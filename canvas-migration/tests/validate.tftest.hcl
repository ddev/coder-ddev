mock_provider "coder" {
  mock_data "coder_workspace" {
    defaults = { start_count = 1, id = "mock-workspace-id", name = "test-workspace" }
  }
  mock_data "coder_workspace_owner" {
    defaults = { name = "testuser", email = "test@example.com" }
  }
  mock_data "coder_parameter" { defaults = { value = "" } }
}
mock_provider "docker" {}
override_data {
  target = data.coder_parameter.project_names
  values = { value = "migration" }
}
override_data {
  target = data.coder_parameter.vscode_extensions
  values = { value = "[]" }
}
override_data {
  target = module.claude_remote_control.data.coder_parameter.enable_claude_code
  values = { value = "true" }
}
override_data {
  target = module.claude_remote_control.data.coder_parameter.claude_code_skip_permissions
  values = { value = "true" }
}
run "migration_defaults" {
  command = plan
  assert {
    condition     = length(coder_app.ddev_web) == 1 && coder_app.ddev_web["migration"].share == "owner" && coder_app.storybook.share == "owner"
    error_message = "One migration project and private apps are required."
  }
  assert {
    condition     = data.coder_parameter.project_names.default == "migration" && !data.coder_parameter.project_names.mutable
    error_message = "Project name must default to migration and be immutable."
  }
  assert {
    condition     = module.claude_remote_control.app_count == 1 && strcontains(coder_agent.main.startup_script, "--dangerously-skip-permissions")
    error_message = "Claude remote control and skip prompts must default on."
  }
  assert {
    condition     = strcontains(coder_agent.main.startup_script, "CLAUDE_RUNNER_ENABLED=\"false\"")
    error_message = "Self-hosted runner must remain off."
  }
  assert {
    condition     = coder_agent.main.env.MIGRATION_SOURCE_URL == "" && coder_agent.main.env.MIGRATION_GIT_REPOSITORY == ""
    error_message = "Migration inputs must be optional."
  }
}
run "sharing" {
  command = plan
  override_data {
    target = data.coder_parameter.share_projects
    values = { value = "true" }
  }
  assert {
    condition     = coder_app.ddev_web["migration"].share == "public" && coder_app.storybook.share == "public" && coder_app.mailpit["migration"].share == "owner"
    error_message = "Only Drupal and Storybook should become public."
  }
}
run "optional_inputs_are_environment_only" {
  command = plan
  override_data {
    target = data.coder_parameter.migration_source_url
    values = { value = "https://example.com/?q='quoted'" }
  }
  override_data {
    target = data.coder_parameter.migration_git_repository
    values = { value = "git@example.com:team/output.git" }
  }
  assert {
    condition     = coder_agent.main.env.MIGRATION_SOURCE_URL == "https://example.com/?q='quoted'" && !strcontains(coder_agent.main.startup_script, "q='quoted'")
    error_message = "Optional inputs must not be interpolated into executable shell."
  }
}
run "stopped_workspace" {
  command = plan
  override_data {
    target = data.coder_workspace.me
    values = { start_count = 0, id = "mock-workspace-id", name = "test-workspace" }
  }
  assert {
    condition     = length(docker_container.workspace) == 0 && docker_volume.coder_dind_cache.name == "coder-testuser-test-workspace-dind-cache"
    error_message = "Stopping must remove compute while retaining the named Docker volume."
  }
}
run "default_launch_starts_claude_in_project" {
  command = plan
  assert {
    condition     = !strcontains(coder_agent.main.startup_script, "claude-launch") && strcontains(coder_agent.main.startup_script, "-c \"/home/coder/migration\"")
    error_message = "Without /building-ui, Claude must start with the default command in the project directory."
  }
}
run "start_building_ui_uses_launch_script" {
  command = plan
  override_data {
    target = data.coder_parameter.start_building_ui
    values = { value = "true" }
  }
  assert {
    condition     = strcontains(coder_agent.main.startup_script, "CLAUDE_REMOTE_CMD=\"SSH_AUTH_SOCK=/home/coder/.ssh-agent-relay/agent.sock /home/coder/.local/bin/claude-launch\"") && strcontains(coder_agent.main.startup_script, base64encode(file("start-building-ui.sh")))
    error_message = "/building-ui must replace the remote-control command with start-building-ui.sh."
  }
  assert {
    condition     = !strcontains(coder_agent.main.startup_script, "|| [ \"$CURRENT_CMD\" != \"claude\" ]")
    error_message = "A running launch script must not be respawned because it is not claude."
  }
}
