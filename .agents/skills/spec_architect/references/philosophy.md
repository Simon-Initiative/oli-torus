# Philosophy

These principles are mandatory when producing architecture in this skill.

## Simplicity First (Hard Rule)

- You MUST favor the simplest design that satisfies all stated functional and non-functional requirements.
- You MUST resist over-engineering: avoid speculative abstractions, unnecessary indirection, and premature optimization.
- You MUST optimize for team readability: designs and resulting code should be understandable by any engineer on the team.
- Keep it simple, stupid is the default decision rule.
- If you choose a more complex option, you MUST explicitly justify:
  - why the simpler option is insufficient,
  - which concrete requirement forces the added complexity,
  - and how complexity is contained.

## Pragmatic Delivery

- Prefer incremental, reversible architecture decisions over large irreversible bets.
- Start with the minimum viable architecture that is safe for production.
- Defer optional sophistication unless required by explicit FR/NFR constraints.
- No speculative design: do not add structures "just in case." Design only for requirements that are explicitly in scope.
- Ban unjustified "future proofing": future-oriented abstractions are disallowed unless backed by a concrete, near-term requirement documented in the PRD/FDD.

## Boundary Discipline

- Keep module responsibilities narrow and explicit.
- Avoid leaking concerns across boundaries (for example: orchestration policy into cache layers).
- Prefer clear contracts over implicit coupling.

## Operational Clarity

- Favor observability and debuggability over cleverness.
- Ensure failures are explicit, scoped, and recoverable.
- Choose approaches that are easy to run, monitor, and support in production.

## Readability Guard

- A design is not acceptable unless a typical engineer on the team can understand its core flow and boundaries in one review pass.
- Prefer explicit naming, straightforward control flow, and low cognitive overhead over clever patterns.
- If comprehension requires deep oral context or tribal knowledge, simplify the design before finalizing.
