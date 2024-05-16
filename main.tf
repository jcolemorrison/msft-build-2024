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