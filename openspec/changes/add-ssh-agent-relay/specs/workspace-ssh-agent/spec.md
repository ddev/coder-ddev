## ADDED Requirements

### Requirement: Coder Key Agent
The workspace startup script SHALL load the Coder-managed SSH key into an `ssh-agent` on `~/.coder-ssh-agent/agent.sock` on every workspace start, without writing the key to disk and without failing workspace startup.

#### Scenario: Key loads
- **WHEN** a workspace starts
- **THEN** `SSH_AUTH_SOCK=~/.coder-ssh-agent/agent.sock ssh-add -l` SHALL list the Coder key

#### Scenario: Key fetch fails
- **WHEN** the agent can't start or the key can't be fetched
- **THEN** the startup script SHALL print a warning and continue

### Requirement: SSH Agent Relay for DDEV
The workspace SHALL provide a stable agent socket at `~/.ssh-agent-relay/agent.sock` that connects each client to the first live agent of: the forwarded agent recorded by the most recent interactive shell, the newest live forwarded agent in `/tmp/auth-agent*/listener.sock`, and the Coder key agent. DDEV's global `ssh_agent_upstream` SHALL point at this socket.

#### Scenario: Nothing forwarded
- **WHEN** no client forwards an SSH agent
- **THEN** `ddev exec ssh-add -l` SHALL list the Coder key

#### Scenario: Forwarded agent
- **WHEN** a user opens a terminal through VS Code Remote or `coder ssh -A` with a forwarded agent
- **THEN** DDEV's containers and that terminal SHALL use the forwarded agent's keys

#### Scenario: Reconnect
- **WHEN** the forwarded agent that was in use goes away
- **THEN** the relay SHALL use the next live forwarded agent, or the Coder key agent if none is left, without restarting DDEV projects

#### Scenario: Hung forwarded agent
- **WHEN** a forwarded agent socket doesn't respond
- **THEN** a new interactive shell SHALL start within about 2 seconds per liveness check, and SHALL NOT set `SSH_AUTH_SOCK` to that socket
