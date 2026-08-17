mock_provider "oci" {}
mock_provider "random" {}
mock_provider "time" {}

variables {
  tenancy_ocid     = "ocid1.tenancy.oc1..ormv2regiontest"
  region           = "ap-tokyo-1"
  compartment_ocid = "ocid1.compartment.oc1..ormv2regiontest"
  admin_email      = "admin@example.invalid"
}

run "osaka_subscription_selects_kix" {
  command = plan

  variables {
    deployment_region = "大阪（ap-osaka-1・推奨）"
  }

  override_data {
    target = data.oci_identity_region_subscriptions.this
    values = {
      region_subscriptions = [
        {
          is_home_region = true
          region_key     = "NRT"
          region_name    = "ap-tokyo-1"
          state          = "READY"
          tenancy_id     = "ocid1.tenancy.oc1..ormv2regiontest"
        },
        {
          is_home_region = false
          region_key     = "KIX"
          region_name    = "ap-osaka-1"
          state          = "READY"
          tenancy_id     = "ocid1.tenancy.oc1..ormv2regiontest"
        },
      ]
    }
  }

  assert {
    condition     = local.deploy_region == "ap-osaka-1" && local.deploy_region_key == "kix"
    error_message = "The Osaka choice must resolve to ap-osaka-1 and the kix OCIR registry."
  }

  assert {
    condition     = local.deploy_region_subscribed
    error_message = "A subscribed Osaka region must pass preflight."
  }
}

run "chicago_subscription_selects_ord" {
  command = plan

  variables {
    deployment_region = "シカゴ（us-chicago-1）"
  }

  override_data {
    target = data.oci_identity_region_subscriptions.this
    values = {
      region_subscriptions = [
        {
          is_home_region = true
          region_key     = "NRT"
          region_name    = "ap-tokyo-1"
          state          = "READY"
          tenancy_id     = "ocid1.tenancy.oc1..ormv2regiontest"
        },
        {
          is_home_region = false
          region_key     = "ORD"
          region_name    = "us-chicago-1"
          state          = "READY"
          tenancy_id     = "ocid1.tenancy.oc1..ormv2regiontest"
        },
      ]
    }
  }

  assert {
    condition     = local.deploy_region == "us-chicago-1" && local.deploy_region_key == "ord"
    error_message = "The Chicago choice must resolve to us-chicago-1 and the ord OCIR registry."
  }

  assert {
    condition     = local.deploy_region_subscribed
    error_message = "A subscribed Chicago region must pass preflight."
  }
}

run "unsubscribed_chicago_stops_preflight" {
  command = plan

  variables {
    deployment_region = "シカゴ（us-chicago-1）"
  }

  override_data {
    target = data.oci_identity_region_subscriptions.this
    values = {
      region_subscriptions = [
        {
          is_home_region = true
          region_key     = "NRT"
          region_name    = "ap-tokyo-1"
          state          = "READY"
          tenancy_id     = "ocid1.tenancy.oc1..ormv2regiontest"
        },
      ]
    }
  }

  expect_failures = [terraform_data.preflight]
}
