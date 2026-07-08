# AGENTS.md

This repository is a learning project for implementing ActiveRecord-style ORM
internals in Ruby. Agents should optimize for understanding, incremental
progress, and clear explanations rather than feature volume.

## Project Intent

The project explores how ActiveRecord-style ORMs work underneath common
high-level APIs such as Rails Active Record, Sequel, ROM, and direct model query
interfaces.

The learner is already comfortable with Ruby and basic backend or Web
development, so avoid spending too much time on basic Ruby syntax or ordinary
application structure. Prefer deeper discussion of database connections, SQL
execution, model mapping, query construction, persistence, transactions,
associations, schema handling, validations, callbacks, and tradeoffs hidden by
ORM convenience APIs.

## Working Style

- Proceed step by step.
- Treat a request to proceed to the next step as permission to advance one small
  learning unit, not to complete an entire roadmap section, unless the user
  explicitly asks for a full section.
- Before a major implementation step, clarify the specific learning objective.
- After a meaningful implementation step, summarize what was learned and what
  remains unclear.
- Keep changes small and inspectable.
- Prefer Ruby standard library behavior first when the goal is to understand the
  mechanism.
- Use external libraries only when they help compare designs, provide a database
  driver boundary, or when the learner explicitly wants to study that library.
- Keep `TODO.md` updated as a living roadmap, not a fixed plan.
- If the learning direction changes, update the roadmap instead of forcing the
  original plan.

## Implementation Guidance

- Prefer starting with an explicit SQLite-backed model layer before copying the
  full behavior of Rails Active Record.
- Make connection, adapter, SQL execution, row hydration, model, and query
  boundaries explicit once each boundary has a learning reason to exist.
- Keep SQL generation explicit enough to study. Small query builders and clear
  bind-parameter handling are preferred over opaque shortcuts when the topic is
  ORM behavior.
- Be careful with SQL injection, type casting, missing rows, nil values, object
  mutation, dirty tracking, transaction boundaries, and source of truth between
  Ruby objects and database rows.
- When introducing abstractions such as adapters, model base classes, relation
  objects, attribute sets, association proxies, migration runners, or callback
  chains, explain what problem the abstraction solves and which behavior it
  hides.
- When comparing with Rails Active Record, Sequel, ROM, or direct SQL, focus on
  the underlying behavior rather than surface API convenience.
- Include tests or small reproducible examples where practical, especially for
  SQL execution, bind parameters, row mapping, missing records, query
  composition, persistence, transactions, and associations.

## Documentation Guidance

- `README.md` should describe the project purpose and scope.
- `TODO.md` should track the current learning roadmap, progress, and open
  questions.
- Add notes to `TODO.md` when a completed step changes the next learning
  direction.
- Add topic-specific notes under `docs/` once an implementation step creates a
  useful learning artifact.
- Use `LEARNING_PROJECT.md` only as background for the reusable learning-project
  pattern; keep this file focused on `_acrc` execution guidance.
