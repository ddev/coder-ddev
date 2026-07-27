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
  # Default mock for coder_parameter. vscode_extensions expects "[]" (valid JSON array).
  # project_names falls back to workspace name when value is "[]" (handled in locals).
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

run "single_project_default" {
  command = plan
  assert {
    condition     = length(coder_app.ddev_web) == 1
    error_message = "should have exactly 1 coder_app.ddev_web with default (workspace name)"
  }
  assert {
    condition     = contains(keys(coder_app.ddev_web), "test-workspace")
    error_message = "default project slug should be the workspace name"
  }
}

run "two_projects" {
  command = plan
  override_data {
    target = data.coder_parameter.project_names
    values = {
      value = "drupal,wordpress"
    }
  }
  assert {
    condition     = length(coder_app.ddev_web) == 2
    error_message = "should have 2 coder_app.ddev_web instances for two project names"
  }
  assert {
    condition     = contains(keys(coder_app.ddev_web), "drupal")
    error_message = "coder_app.ddev_web[\"drupal\"] should exist"
  }
  assert {
    condition     = contains(keys(coder_app.ddev_web), "wordpress")
    error_message = "coder_app.ddev_web[\"wordpress\"] should exist"
  }
}

run "two_projects_with_spaces" {
  command = plan
  override_data {
    target = data.coder_parameter.project_names
    values = {
      value = "drupal, wordpress"
    }
  }
  assert {
    condition     = length(coder_app.ddev_web) == 2
    error_message = "spaces around project names should be trimmed"
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

run "linuxbrew_volume_created" {
  command = plan
  assert {
    condition     = docker_volume.coder_linuxbrew.name == "coder-testuser-test-workspace-linuxbrew"
    error_message = "docker_volume.coder_linuxbrew must be named per the coder-<owner>-<workspace>-linuxbrew convention"
  }
}
