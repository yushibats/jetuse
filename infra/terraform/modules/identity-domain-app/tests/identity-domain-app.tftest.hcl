mock_provider "oci" {}

variables {
  prefix        = "jetuse-domain-test"
  idcs_endpoint = "https://idcs-test.identity.oraclecloud.com"
  redirect_uri  = "https://example.invalid/"
  demo_email    = "admin@example.invalid"
  demo_password = "NotARealPassword_123"
  home_region   = "ap-osaka-1"
}

run "new_domain_manages_required_signing_setting" {
  command = plan

  assert {
    condition     = length(oci_identity_domains_setting.this) == 1
    error_message = "A stack-created domain must publish its signing certificate for JWT verification."
  }

  assert {
    condition     = oci_identity_domains_user.demo.user_name == "demo"
    error_message = "The existing ORM default login name must remain backward compatible."
  }
}

run "existing_domain_is_not_modified" {
  command = plan

  variables {
    manage_domain_settings = false
    demo_username          = "jetuse-domain-test-admin"
  }

  assert {
    condition     = length(oci_identity_domains_setting.this) == 0
    error_message = "Attaching JetUse to an existing domain must not modify domain-wide settings."
  }

  assert {
    condition     = oci_identity_domains_user.demo.user_name == "jetuse-domain-test-admin"
    error_message = "ORM v2 must be able to use a stack-specific username in a shared domain."
  }
}
