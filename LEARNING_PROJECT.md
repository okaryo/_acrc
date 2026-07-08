# Learning Project Pattern

This document describes a reusable way to run AI-assisted learning projects.
It can be copied into a new repository and adapted to the subject being studied.

## Purpose

Use small implementation projects to understand how a tool, system, protocol,
or library works internally.

The project should optimize for learning and inspectability rather than feature
volume. A successful project does not need to become production-ready. It should
make the important mechanisms visible.

## Core Principles

- Define the learning goal before expanding the roadmap.
- Define non-goals so the project does not drift into a production rewrite.
- Start with a deliberately small core milestone.
- Make the first milestone small enough that the source-to-result lifecycle is
  visible quickly.
- Treat roadmap sections as learning themes, not as single implementation
  steps.
- Treat "proceed to the next step" as a request to advance the next useful
  learning unit, not to complete an entire roadmap section.
- Confirm the learning objective before starting a major implementation step.
- Keep changes small, inspectable, and explainable.
- Prefer standard library or minimal local implementations when the goal is to
  understand the mechanism.
- Add external dependencies only when they directly support a learning question.
- Record decisions, direction changes, open questions, and completed learning
  units as the project evolves.
- Update the roadmap when the learning direction changes instead of forcing the
  original plan.
- Separate optional advanced topics from the core milestone.
- Mark the core milestone complete once the original learning purpose has been
  met, even if optional explorations remain.

## Recommended Project Documents

- `README.md`: project purpose, scope, non-goals, how to run the project, and
  the current achievement level.
- `AGENTS.md`: execution instructions for AI agents working in that repository.
  Keep this focused on project-specific working rules.
- `TODO.md`: a living roadmap, current milestone status, completed learning
  units, and open questions.
- `docs/`: topic-specific learning notes created when an implementation step
  produces a useful explanation.
- `examples/`: small executable examples that reproduce important behavior or
  comparisons.

## Roadmap Shape

A useful roadmap starts with a core path and ends with optional exploration.

The core path should answer:

- What is the smallest useful version of the thing being studied?
- What boundaries or components need to become visible?
- What behavior must be tested or demonstrated?
- What decisions are intentionally out of scope?

Optional advanced topics should be clearly marked as optional. They are useful
when a new learning question appears, but they should not make the core project
feel unfinished.

## Completion Criteria

The core milestone can be marked complete when:

- The original learning goal has been met.
- The main internal boundaries are visible in code or examples.
- The project has tests or reproducible examples for the important behavior.
- The roadmap records what was completed and what remains optional.
- Known limitations are documented instead of being treated as hidden failure.

After that point, future work should start from a specific learning question.
Optional topics can remain in the roadmap without being treated as incomplete
core work.
