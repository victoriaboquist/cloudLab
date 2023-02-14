terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.25.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  resource_group_name           = "rg-${var.environment}-${var.location}-${var.name}"
  app_service_plan_name         = "asp-${var.environment}-${var.location}-${var.name}"
  app_service_name              = "wa-${var.environment}-${var.location}-${var.name}"
  azure_container_registry_name = "acr${var.environment}${var.location}${var.name}"
}

resource "azurerm_resource_group" "this" {
  name     = local.resource_group_name
  location = var.location_long
}

resource "azurerm_service_plan" "this" {
  name                = local.app_service_plan_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "this" {
  name                = local.app_service_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  service_plan_id     = azurerm_service_plan.this.id

  site_config {
    application_stack {
      docker_image     = "${azurerm_container_registry.this.login_server}/${var.container_name}"
      docker_image_tag = "latest"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "DOCKER_REGISTRY_SERVER_URL"          = "https://${azurerm_container_registry.this.login_server}"
    "DOCKER_REGISTRY_SERVER_USERNAME"     = azurerm_container_registry.this.admin_username
    "DOCKER_REGISTRY_SERVER_PASSWORD"     = azurerm_container_registry.this.admin_password
    "DOCKER_ENABLE_CI"                    = "true"
    "WEBSITES_PORT"                       = "8080"
    "PORT"                                = "8080"
  }

  lifecycle {
    ignore_changes = [
      site_config[0].application_stack[0].docker_image_tag,
    ]
  }
}

resource "azurerm_container_registry" "this" {
  name                = local.azure_container_registry_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_container_registry_webhook" "this" {
  name                = "webhook${replace(azurerm_linux_web_app.this.name, "-", "")}"
  registry_name       = azurerm_container_registry.this.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  service_uri = "https://${azurerm_linux_web_app.this.site_credential[0].name}:${azurerm_linux_web_app.this.site_credential[0].password}@${azurerm_linux_web_app.this.name}.scm.azurewebsites.net/docker/hook"
  status      = "enabled"
  scope       = "${var.container_name}:latest"
  actions     = ["push"]
}