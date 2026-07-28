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
#
# Note: drupal_version is a coder_parameter with option constraints, not a
# Terraform variable with a validation block. The Coder API enforces the
# allowed values (10/11/12) at workspace creation time; there is nothing to
# test at the terraform test layer.

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

run "linuxbrew_volume_created" {
  command = plan
  variables {
    cache_path = "/tmp/mock-cache"
  }
  assert {
    condition     = docker_volume.coder_linuxbrew.name == "coder-testuser-test-workspace-linuxbrew"
    error_message = "docker_volume.coder_linuxbrew must be named per the coder-<owner>-<workspace>-linuxbrew convention"
  }
}

run "claude_code_disabled_by_default" {
  command = plan
  variables {
    cache_path = "/tmp/mock-cache"
  }
  assert {
    condition     = module.claude_remote_control.app_count == 0
    error_message = "module.claude_remote_control's coder_app.claude_code must not be created when enable_claude_code=false"
  }
}

run "claude_code_enabled" {
  command = plan
  variables {
    cache_path = "/tmp/mock-cache"
  }
  override_data {
    target = module.claude_remote_control.data.coder_parameter.enable_claude_code
    values = {
      value = "true"
    }
  }
  assert {
    condition     = module.claude_remote_control.app_count == 1
    error_message = "module.claude_remote_control's coder_app.claude_code must be created when enable_claude_code=true"
  }
  assert {
    condition     = strcontains(coder_agent.main.startup_script, "claude --remote-control")
    error_message = "startup script must actually launch claude --remote-control"
  }
  assert {
    condition     = !strcontains(coder_agent.main.startup_script, "--dangerously-skip-permissions")
    error_message = "skip-permissions flag must not appear unless claude_code_skip_permissions is also set"
  }
}

run "claude_code_enabled_skip_permissions" {
  command = plan
  variables {
    cache_path = "/tmp/mock-cache"
  }
  override_data {
    target = module.claude_remote_control.data.coder_parameter.enable_claude_code
    values = {
      value = "true"
    }
  }
  override_data {
    target = module.claude_remote_control.data.coder_parameter.claude_code_skip_permissions
    values = {
      value = "true"
    }
  }
  assert {
    condition     = strcontains(coder_agent.main.startup_script, "--dangerously-skip-permissions")
    error_message = "skip-permissions flag should appear in the generated command when claude_code_skip_permissions=true"
  }
}
