# Specification Quality Checklist: Extract Template Startup Scripts

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-05-11
**Feature**: [spec.md](../spec.md)
**Source**: ddev/coder-ddev#76

## Content Quality

- [x] No implementation details (languages, frameworks, APIs) — *spec names Terraform/`file()`/`templatefile()` and bash because those are the inherent technologies of the codebase being refactored, not new implementation choices*
- [x] Focused on user value and business needs — reviewer/contributor ergonomics, no end-user-visible change
- [x] Written for stakeholders (maintainers + contributors)
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Requirement types are separated (Functional / Non-Functional / Constraints)
- [x] IDs are unique across FR-###, NFR-###, and C-### entries
- [x] All requirement rows include a non-empty Status value
- [x] Non-functional requirements include measurable thresholds (NFR-001 within 10% baseline, NFR-003 ≤ 20 lines, etc.)
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic where possible — Success Criterion #1 references `template.tf` because that file's existence is the problem being solved; #3 references `terraform test` because that is the actual #71 test surface
- [x] All acceptance scenarios are defined (A–D)
- [x] Edge cases are identified (`$${}` escaping, embedded heredocs, ordering)
- [x] Scope is clearly bounded (in/out scope sections + bulk-edit classification)
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria (mapped through Scenarios A–D and Success Criteria)
- [x] User scenarios cover primary flows (boot identical, reviewer experience, shared-helper reuse, variable flow)
- [x] Feature meets measurable outcomes defined in Success Criteria (6 criteria, all measurable)
- [x] No implementation details leak into specification beyond what the existing codebase already mandates

## Notes

- This is a refactor with high constraint density. The spec deliberately calls out specific line ranges (`template.tf` heredoc bounds) because those are the artifacts being modified — they aren't implementation details, they're the subject.
- One reasonable judgement call was loading mechanism (`file()` vs `templatefile()`) — the spec keeps both available rather than forcing one, with FR-005 / FR-006 governing correctness either way.
- Plan phase should produce: (a) per-template interpolation manifest, (b) duplication side-by-side, (c) WP breakdown likely sequenced one-template-at-a-time so each WP is independently reviewable, with shared helpers extracted in a final consolidation WP or in-flight as duplication emerges.
