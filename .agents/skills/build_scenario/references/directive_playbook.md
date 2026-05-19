# Directive Playbook

Use this as a quick map when translating requirements into YAML.

## Core lifecycle directives
- Authoring: `project`, `manipulate`, `create_activity`, `edit_page`, `publish`
- Delivery: `section`, `update`, `customize`, `remix`, `clone`
- Identity/org: `institution`, `user`, `enroll`
- Learner simulation: `view_practice_page`, `answer_question`
- Validation/composition: `assert`, `use`, `hook`

## Preferred sequence pattern
1. Build source content (`project` + optional content directives)
2. Publish when delivery semantics matter (`publish`)
3. Create delivery surface (`section`)
4. Create/enroll learners (`user`, `enroll`)
5. Simulate interactions (`view_practice_page`, `answer_question`)
6. Verify outcomes (`assert`)

## Assertion guidance
- `assert.structure`: curriculum/resource hierarchy checks
- `assert.resource`: resource-level field/property checks
- `assert.progress`: completion/progress checks
- `assert.proficiency`: objective proficiency checks

## Reference docs
- `test/support/scenarios/README.md`
- `test/support/scenarios/docs/projects.md`
- `test/support/scenarios/docs/sections.md`
- `test/support/scenarios/docs/content_authoring.md`
- `test/support/scenarios/docs/student_simulation.md`
- `test/support/scenarios/docs/users_and_org.md`
- `test/support/scenarios/docs/hooks.md`
- `lib/oli/scenarios/directive_parser.ex` (current canonical directive/attribute surface)
