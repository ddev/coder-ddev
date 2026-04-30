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

run "plan_succeeds_with_defaults" {
  command = plan
}

run "container_created_when_started" {
  command = plan
  assert {
    condition     = length(docker_container.workspace) == 1
    error_message = "docker_container.workspace must be created when start_count=1"
  }
}

run "adminer_off_by_default" {
  command = plan
  assert {
    condition     = length(coder_app.adminer) == 0
    error_message = "coder_app.adminer must not be created when enable_adminer=false"
  }
}

run "adminer_enabled" {
  command = plan
  variables {
    enable_adminer = true
  }
  assert {
    condition     = length(coder_app.adminer) == 1
    error_message = "coder_app.adminer must be created when enable_adminer=true"
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
