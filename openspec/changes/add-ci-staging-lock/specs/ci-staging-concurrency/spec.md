## ADDED Requirements

### Requirement: Bounded Concurrent CI Workspaces on Staging
The system SHALL ensure no more than a configurable limit `N` of `ci-bot`-owned workspaces are concurrently created/running on the shared staging Coder box, regardless of which workflow file or runner type (self-hosted or GitHub-hosted) initiates them.

#### Scenario: Two jobs start within the same instant
- **WHEN** two or more CI jobs, from any of the integration-test workflows and any runner type, attempt to create a staging workspace at nearly the same time
- **THEN** at most `N` of them SHALL be allowed to proceed to `coder create` concurrently
- **AND** the rest SHALL wait until a slot frees up rather than proceeding or being silently dropped

#### Scenario: A slot is free
- **WHEN** fewer than `N` lock slots are currently held
- **THEN** a job requesting a slot SHALL acquire one and proceed without unnecessary delay

### Requirement: Self-Healing Lock Slots
The locking mechanism SHALL NOT deadlock indefinitely if a job crashes or is force-cancelled after acquiring a slot.

#### Scenario: A job is killed after acquiring a slot
- **WHEN** a CI job acquires a lock slot and is then killed (e.g. a cancelled workflow run or a hard-killed runner) before its release step executes
- **THEN** the abandoned slot SHALL be reclaimed automatically — either by a later contender's staleness check or by the existing staging janitor — within a bounded amount of time
- **AND** no manual intervention SHALL be required to restore CI throughput
