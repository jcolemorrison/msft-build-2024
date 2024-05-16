# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.103.1"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  skip_provider_registration = true
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "build" {
  name     = "build-base-resources"
  location = "East US"
}

# Create a virtual network
resource "azurerm_virtual_network" "main" {
  name                = "mainNetwork"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.build.location
  resource_group_name = azurerm_resource_group.build.name
}

# Create a public subnet
resource "azurerm_subnet" "public" {
  name                 = "publicSubnet"
  resource_group_name  = azurerm_resource_group.build.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create a private subnet
resource "azurerm_subnet" "private" {
  name                 = "privateSubnet"
  resource_group_name  = azurerm_resource_group.build.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "nat" {
  name                = "nat-pip"
  location            = azurerm_resource_group.build.location
  resource_group_name = azurerm_resource_group.build.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "main" {
  name                = "example-natgateway"
  location            = azurerm_resource_group.build.location
  resource_group_name = azurerm_resource_group.build.name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "main" {
  subnet_id      = azurerm_subnet.private.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

# Create a bastion subnet
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.build.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/27"]
}

# Create a public IP for the bastion host
resource "azurerm_public_ip" "bastion" {
  name                = "bastion-pip"
  location            = azurerm_resource_group.build.location
  resource_group_name = azurerm_resource_group.build.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create the bastion host
resource "azurerm_bastion_host" "main" {
  name                = "main-bastion"
  location            = azurerm_resource_group.build.location
  resource_group_name = azurerm_resource_group.build.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

# Create a Cognitive Services Account
resource "azurerm_cognitive_account" "openai" {
  name                = "openai-ca"
  location            = azurerm_resource_group.build.location
  resource_group_name = azurerm_resource_group.build.name
  kind                = "OpenAI"
  sku_name            = "F0"
  public_network_access_enabled = false
  custom_subdomain_name = "build-openai"
}

# Creates a private DNS zone named "privatelink.openai.azure.com" in the specified resource group.
resource "azurerm_private_dns_zone" "openai" {
  name                = "privatelink.openai.azure.com"
  resource_group_name = azurerm_resource_group.build.name
}

# Creates a private endpoint in the specified resource group and subnet.
# The private endpoint is associated with a Cognitive Services account.
# The private endpoint allows you to securely access the Cognitive Services account over a private network connection.
resource "azurerm_private_endpoint" "openai" {
  name                = "pe-openai-we"
  location            = azurerm_resource_group.build.location
  resource_group_name = azurerm_resource_group.build.name
  subnet_id           = azurerm_subnet.private.id

  # Specifies the details of the connection to the Cognitive Services account.
  private_service_connection {
    name                           = "pe-openai-we"
    private_connection_resource_id = azurerm_cognitive_account.openai.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  # Associates the private endpoint with the private DNS zone created earlier.
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.openai.id]
  }
}

# Creates a link between the private DNS zone and a virtual network.
# This allows the DNS zone to resolve names for resources within the virtual network.
resource "azurerm_private_dns_zone_virtual_network_link" "openai" {
  name                  = "openai-vnet-link"
  resource_group_name   = azurerm_resource_group.build.name
  private_dns_zone_name = azurerm_private_dns_zone.openai.name
  virtual_network_id    = azurerm_virtual_network.main.id
}