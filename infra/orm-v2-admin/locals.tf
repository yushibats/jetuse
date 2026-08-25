locals {
  deployment_regions = {
    "大阪（ap-osaka-1・推奨）" = {
      name = "ap-osaka-1"
      key  = "kix"
    }
    "シカゴ（us-chicago-1）" = {
      name = "us-chicago-1"
      key  = "ord"
    }
  }
  deploy_region     = local.deployment_regions[var.deployment_region].name
  deploy_region_key = local.deployment_regions[var.deployment_region].key

  region_subscriptions_readable = try(length(data.oci_identity_region_subscriptions.this.region_subscriptions) > 0, false)
  deploy_region_subscribed = try(contains(
    [for subscription in data.oci_identity_region_subscriptions.this.region_subscriptions : subscription.region_name],
    local.deploy_region,
  ), false)
  home_region = try([
    for subscription in data.oci_identity_region_subscriptions.this.region_subscriptions :
    subscription.region_name if subscription.is_home_region
  ][0], var.region)
}
