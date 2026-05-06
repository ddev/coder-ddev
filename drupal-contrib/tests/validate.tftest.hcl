mock_provider "coder" {
  mock_data "coder_workspace" {
    defaults = {
      start_count = 1
      id          = "mock-workspace-id"
      name        = "test-workspace"
    }
  }
  mock_data "coder_workspace_owner" {
    defaults = {
      name = "testuser"
    }
  }
  # vscode_extensions.value is jsondecode()d in locals; must be valid JSON
  mock_data "coder_parameter" {
    defaults = {
      value = "[]"
    }
  }
}

mock_provider "docker" {}

# project_name has no default (validation requires non-empty) so we override it in every run block.
# The mock coder_parameter value "[]" is used for all parameters by default; individual run blocks
# override specific parameters where the value matters for assertions.
#
# Note: drupal_version and project_type are coder_parameters with option constraints, not
# Terraform variables with validation blocks. The Coder API enforces allowed values at workspace
# creation time; there is nothing to test at the terraform test layer.

run "plan_succeeds_with_token_module" {
  command = plan

  # project_name must be a valid machine name; use a well-known module for tests
  variables {
    # project_name is validated by coder_parameter regex at API level; no tf var to override
  }
}

run "container_created_when_started" {
  command = plan

  assert {
    condition     = length(docker_container.workspace) == 1
    error_message = "docker_container.workspace must be created when start_count=1"
  }
}

run "cpu_below_minimum" {
  command = plan
  variables {
    cpu = 0
  }
  expect_failures = [var.cpu]
}

run "cpu_above_maximum" {
  command = plan
  variables {
    cpu = 33
  }
  expect_failures = [var.cpu]
}

run "memory_below_minimum" {
  command = plan
  variables {
    memory = 1
  }
  expect_failures = [var.memory]
}

run "memory_above_maximum" {
  command = plan
  variables {
    memory = 129
  }
  expect_failures = [var.memory]
}
