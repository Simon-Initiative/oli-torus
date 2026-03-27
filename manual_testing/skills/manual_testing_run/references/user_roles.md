# User Roles

Manual browser execution depends heavily on role. The same URL can behave differently for different users.

## Authors

Main motivations:
- create and refine course content
- manage page structure
- review draft state
- publish updates

Typical capabilities:
- access authoring projects
- open editors
- change content and settings
- see publish and revision-oriented controls

Testing cues:
- editable rich-content surfaces
- authoring navigation or project structure panels
- actions such as edit, publish, preview, or organize

## Instructors

Main motivations:
- manage an active course section
- review learner-facing content in delivery
- monitor or configure section behavior

Typical capabilities:
- open delivery sections
- view learner-accessible pages
- access instructor-oriented section actions when enabled

Testing cues:
- section home or section navigation
- delivery pages with course navigation and learner-visible content
- some management controls, but not full authoring editors

## Learners

Main motivations:
- enter a section
- navigate course content
- complete activities and assessments

Typical capabilities:
- open assigned or available content
- move through learner navigation
- interact with activities

Testing cues:
- simpler navigation focused on course progress and content access
- no authoring controls
- content pages optimized for reading and interaction rather than editing

## Role Discipline
- Match the case to the least-privileged role that can execute it.
- If the caller provides more power than needed, do not rely on privileged-only controls unless the case requires them.
- If the visible UI suggests the wrong role, stop and report a blocked or failed precondition instead of forcing the flow.
