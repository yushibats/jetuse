mock_provider "oci" {}
mock_provider "oci" {
  alias = "home"
}
mock_provider "random" {}
mock_provider "time" {}

variables {
  tenancy_ocid                  = "ocid1.tenancy.oc1..ormv2profiletest"
  compartment_ocid              = "ocid1.compartment.oc1..ormv2profiletest"
  deployment_region_label       = "大阪（ap-osaka-1・推奨）"
  deploy_region                 = "ap-osaka-1"
  deploy_region_key             = "kix"
  home_region                   = "ap-tokyo-1"
  region_subscriptions_readable = true
  deploy_region_subscribed      = true
  admin_email                   = "admin@example.invalid"
  identity_domain_mode          = "新しく作成（推奨）"
  image_tag                     = "test"
  spa_dist_dir                  = "tests/fixtures/spa"
}

run "tenancy_admin_creates_dynamic_groups" {
  command = plan

  variables {
    create_dynamic_groups = true
  }

  assert {
    condition = (
      output.runtime_dynamic_group != null
      && output.adb_dynamic_group != null
      && output.semantic_store_dynamic_group != null
    )
    error_message = "The tenancy-admin profile must create all JetUse dynamic groups."
  }

  assert {
    condition     = length(data.oci_identity_dynamic_groups.existing) == 0
    error_message = "The tenancy-admin profile must not look up an existing dynamic group."
  }
}

run "compartment_admin_reuses_valid_dynamic_group" {
  command = plan

  variables {
    create_dynamic_groups       = false
    existing_dynamic_group_name = "jetuse-prepared-dg"
  }

  override_data {
    target = data.oci_identity_dynamic_groups.existing[0]
    values = {
      dynamic_groups = [{
        compartment_id = "ocid1.tenancy.oc1..ormv2profiletest"
        description    = "JetUse prepared runtime principals"
        id             = "ocid1.dynamicgroup.oc1..ormv2profiletest"
        matching_rule  = <<-RULE
          Any {all {resource.type='computecontainerinstance', resource.compartment.id='ocid1.compartment.oc1..ormv2profiletest'},
               all {resource.type='fnfunc', resource.compartment.id='ocid1.compartment.oc1..ormv2profiletest'},
               all {resource.type='autonomousdatabase', resource.compartment.id='ocid1.compartment.oc1..ormv2profiletest'},
               all {resource.type='generativeaisemanticstore', resource.compartment.id='ocid1.compartment.oc1..ormv2profiletest'},
               all {resource.type='generativeaihostedapplication', resource.compartment.id='ocid1.compartment.oc1..ormv2profiletest'},
               all {resource.type='generativeaihostedapplicationiam', resource.compartment.id='ocid1.compartment.oc1..ormv2profiletest'},
               all {resource.type='generativeaihosteddeployment', resource.compartment.id='ocid1.compartment.oc1..ormv2profiletest'}}
        RULE
        name           = "jetuse-prepared-dg"
        state          = "ACTIVE"
      }]
    }
  }

  assert {
    condition = (
      output.runtime_dynamic_group == "jetuse-prepared-dg"
      && output.adb_dynamic_group == "jetuse-prepared-dg"
      && output.semantic_store_dynamic_group == "jetuse-prepared-dg"
    )
    error_message = "The compartment-admin profile must not create tenancy-level dynamic groups."
  }

  assert {
    condition     = local.existing_dynamic_group_contract_valid
    error_message = "The reviewed seven-resource matching rule must pass preflight."
  }

}

run "compartment_admin_rejects_incomplete_matching_rule" {
  command = plan

  variables {
    create_dynamic_groups       = false
    existing_dynamic_group_name = "jetuse-incomplete-dg"
  }

  override_data {
    target = data.oci_identity_dynamic_groups.existing[0]
    values = {
      dynamic_groups = [{
        compartment_id = "ocid1.tenancy.oc1..ormv2profiletest"
        description    = "Missing hosted agent principals"
        id             = "ocid1.dynamicgroup.oc1..ormv2incomplete"
        matching_rule  = "All {resource.type='computecontainerinstance', resource.compartment.id='ocid1.compartment.oc1..ormv2profiletest'}"
        name           = "jetuse-incomplete-dg"
        state          = "ACTIVE"
      }]
    }
  }

  expect_failures = [terraform_data.preflight]
}

run "compartment_admin_rejects_missing_dynamic_group" {
  command = plan

  variables {
    create_dynamic_groups       = false
    existing_dynamic_group_name = "jetuse-missing-dg"
  }

  override_data {
    target = data.oci_identity_dynamic_groups.existing[0]
    values = {
      dynamic_groups = []
    }
  }

  expect_failures = [terraform_data.preflight]
}
