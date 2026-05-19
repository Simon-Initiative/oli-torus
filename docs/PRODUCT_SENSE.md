# Product Sense

## Product Goals

OLI Torus is a learning engineering platform for authoring, delivering, and improving online course experiences. At a high level, the product exists to help institutions create high-quality instructional materials, publish them safely into learner-facing course sections, integrate those sections with LMS workflows, and generate the data needed to continuously improve teaching and learning.

The product should feel like:

- a durable course-authoring system, not just a content editor
- a reliable delivery platform for instructors and learners
- a strong LMS-integrated tool rather than a standalone learning silo
- a platform that supports learning science, analytics, and iterative improvement over time

## Key Users

- Authors: create, organize, revise, and publish learning materials, assessments, and activities
- Instructors: configure and teach course sections, manage delivery settings, and monitor learner progress
- Students: consume course materials, complete activities, and receive feedback and grades
- System administrators: manage institutions, integrations, policies, registrations, and platform operations
- Researchers and learning engineers: study outcomes, inspect behavior, and use platform data to improve instruction and product decisions

## Core Use Cases

- Author and publish materials: build course structure, create pages and activities, review revisions, and publish stable versions for delivery
- Teach a course section: create sections from published materials, customize section behavior, schedule delivery, and coordinate with LMS-driven workflows
- Students learn concepts: move through instructional content, complete practice and graded work, and receive scoring or feedback
- Administrators support the system: manage institutions, LTI registrations, permissions, and operational policies needed to keep delivery working
- Improve courses over time: analyze learner behavior and outcomes, revise content, republish, and roll updates forward into new or existing delivery contexts

## Product Boundaries And Priorities

- Torus is strongest when it owns course authoring, publication, delivery runtime, and learning activity behavior
- Torus deliberately leans on LMS platforms for surrounding functions such as roster management and core LMS workflows
- The publication model matters because authors need forward progress without destabilizing live learner experiences
- Extensibility matters because new activity types and instructional patterns are part of the product’s long-term value
- Analytics matters because the product is not only for content delivery but also for continuous learning improvement

## Canonical References

- Product and system introduction: `docs/design-docs/introduction.md`
- Roles and core ontology: `docs/design-docs/high-level.md`
- Publication model: `docs/design-docs/publication-model.md`
- Activity concepts: `guides/activities/overview.md`
