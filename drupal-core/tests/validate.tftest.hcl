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

# cache_path has no default so must be supplied in every run block.
# Any path works here — the mock docker provider does not validate host paths.

run "plan_succeeds_with_defaults" {
  command = plan
  variables {
    cache_path = "/tmp/mock-cache"
  }
}

run "container_created_when_started" {
  command = plan
  variables {
    cache_path = "/tmp/mock-cache"
  }
  assert {
    condition     = length(docker_container.workspace) == 1
    error_message = "docker_container.workspace must be created when start_count=1"
  }
}

run "cpu_below_minimum" {
  command = plan
  variables {
    cache_path = "/tmp/mock-cache"
    cpu        = 0
  }
  expect_failures = [var.cpu]
}

run "cpu_above_maximum" {
  command = plan
  variables {
    cache_path = "/tmp/mock-cache"
    cpu        = 33
  }
  expect_failures = [var.cpu]
}

run "memory_below_minimum" {
  command = plan
  variables {
    cache_path = "/tmp/mock-cache"
    memory     = 1
  }
  expect_failures = [var.memory]
}

run "memory_above_maximum" {
  command = plan
  variables {
    cache_path = "/tmp/mock-cache"
    memory     = 129
  }
  expect_failures = [var.memory]
}
