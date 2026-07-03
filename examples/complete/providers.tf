provider "azurerm" {
  features {}

  storage_use_azuread = true
  use_oidc            = true
}

# azapi seeds the example incidents through the Sentinel incidents API; it authenticates exactly
# like azurerm (OIDC in CI, az CLI locally).
provider "azapi" {
  use_oidc = true
}
