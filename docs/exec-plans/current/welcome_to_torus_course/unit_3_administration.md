# Welcome to Torus Course

## Unit 3: Administration Detailed Design

Last updated: 2026-03-26

This document expands Unit 3 from the outline in `overview.md`. It is intended to be the Phase 2 detail pass for the Administration unit and to serve as the source material for later page authoring and MCP-based activity creation.

## Unit Goal

By the end of Unit 3, a learner should be able to:

- explain the role of administration in enabling authoring and delivery
- distinguish users, authors, institutions, registrations, and deployments
- describe the practical purpose of LTI-related administration
- identify the main operational and governance surfaces used by admins
- recognize when an issue belongs to account administration, integration setup, or platform operations

## Unit Vocabulary

Use these terms consistently throughout the unit:

- Administrator
- System admin
- Account admin
- User
- Author
- Institution
- Registration
- Deployment
- External tool
- Publisher
- Ingest
- Research consent
- MCP token

## Module 3.1: Institutions, Roles, and Access

### Module Goal

Teach learners how Torus access and organizational boundaries are structured from an administration point of view.

### Learning Objectives

After this module, the learner should be able to:

- describe what administration owns in Torus
- distinguish user and author management responsibilities
- explain why institutions matter in the platform model
- describe how role and access choices affect the rest of the platform

### Page Plan

#### Page 1: What Administration Owns

Summary:

- Define administration as the capability that makes authoring and delivery possible at scale.
- Clarify the difference between routine authoring work and administrative responsibility.

Key teaching points:

- admins enable the environment in which authors and instructors work
- administration covers access, institutions, integrations, and operational support
- not every product task belongs to the admin role

Suggested formative activity:

- Type: `oli_multiple_choice`
- Prompt idea: Which statement best describes the role of administration in Torus?

#### Page 2: Managing Users, Authors, and Permissions

Summary:

- Introduce the separate surfaces for users and authors.
- Explain that account administration affects who can perform downstream work.

Key teaching points:

- user and author records support different responsibilities
- permissions and role assignments shape access to authoring and admin features
- access management errors can create platform-wide confusion

Suggested formative activity:

- Type: `oli_check_all_that_apply`
- Prompt idea: Which tasks are likely part of account administration?

Media:

- `[Screenshot placeholder: users and authors admin views]`

#### Page 3: Institutions and Organizational Boundaries

Summary:

- Explain why institutions matter in a multi-tenant system.
- Show that institution records are not just labels but operational boundaries.

Key teaching points:

- institutions are a key organizational boundary in Torus
- institution-level setup affects delivery and research/policy behavior
- admins must preserve those boundaries when supporting multiple groups

Suggested formative activity:

- Type: `oli_short_answer`
- Prompt idea: Why is institution setup more than a simple naming task?

Media:

- `[Screenshot placeholder: institutions admin index or institution details]`

### Module 3.1 Scored Assessment Blueprint

Title:

- Admin Access Foundations

Assessment goal:

- verify that the learner understands roles, access, and institution-level administration

Recommended items:

- Item 1: `oli_multiple_choice`
  - Prompt: What is the main responsibility of an administrator compared with an author?
- Item 2: `oli_check_all_that_apply`
  - Prompt: Select the tasks commonly handled through account administration.
- Item 3: `oli_multiple_choice`
  - Scenario: A new staff member needs platform access to manage users. Which kind of concern is this?
- Item 4: `oli_short_answer`
  - Prompt: Why do institutions matter in a multi-tenant learning platform?
- Item 5: `oli_ordering`
  - Prompt: Put these admin concerns in order from broadest platform boundary to specific user access action.
- Item 6: `oli_multiple_choice`
  - Prompt: Which surface is most relevant when reviewing institution-level setup?

Mastery signal:

- learner can explain how roles and institutions shape safe platform access

## Module 3.2: Registrations, Deployments, and Integrations

### Module Goal

Teach learners the admin-facing integration model that supports LMS-connected delivery and related external capabilities.

### Learning Objectives

After this module, the learner should be able to:

- explain why registrations and deployments exist
- describe the admin responsibility for LTI setup at a high level
- identify where external tool and integration records are managed
- use an operational checklist mindset when enabling integrations

### Page Plan

#### Page 1: LTI Concepts for Torus Administrators

Summary:

- Introduce LTI as an integration boundary rather than a deep standards lesson.
- Focus on what an admin needs to know to support authoring and delivery teams.

Key teaching points:

- LMS-integrated delivery depends on administrative setup
- registrations and deployments represent managed integration relationships
- bad integration setup leads to downstream delivery failures

Suggested formative activity:

- Type: `oli_multiple_choice`
- Prompt idea: Why should Torus administrators understand LTI setup even if they are not teaching the course?

#### Page 2: Managing Registrations and Deployments

Summary:

- Show where registrations and deployments live in the admin area.
- Explain these as administrative records that must be created, maintained, and validated.

Key teaching points:

- registrations define integration relationships
- deployments operationalize those relationships for use
- admins must maintain these records carefully because they affect launch behavior

Suggested formative activity:

- Type: `oli_ordering`
- Prompt idea: Put the integration enablement workflow in a sensible order from setup to use.

Media:

- `[Screenshot placeholder: registrations and deployments management UI]`

#### Page 3: External Tools and Delivery Dependencies

Summary:

- Expand beyond core LTI setup to show that external tools and integrations create delivery dependencies.
- Keep focus on admin awareness and support readiness.

Key teaching points:

- external tools can affect what instructors and learners experience
- integration setup is only useful if the full downstream workflow works
- admins should understand dependency chains before declaring setup complete

Suggested formative activity:

- Type: `oli_check_all_that_apply`
- Prompt idea: Which signs suggest an integration issue may affect delivery?

Media:

- `[Screenshot placeholder: external tools admin surfaces]`

#### Page 4: Integration Readiness Checklist

Summary:

- Convert integration concepts into an operational checklist.
- Emphasize validation before rollout.

Key teaching points:

- setup should be reviewed before instructors depend on it
- admins should validate records, context, and expected downstream behavior
- rollout readiness is an operational decision, not only a configuration event

Suggested formative activity:

- Type: `oli_short_answer`
- Prompt idea: What is one item an administrator should verify before considering an LMS integration ready?

### Module 3.2 Scored Assessment Blueprint

Title:

- Integration Readiness Check

Assessment goal:

- verify that the learner understands the purpose and operational care required for admin-managed integrations

Recommended items:

- Item 1: `oli_multiple_choice`
  - Prompt: What is the practical reason administrators manage registrations and deployments?
- Item 2: `oli_ordering`
  - Prompt: Order the high-level path from integration setup to section use.
- Item 3: `oli_check_all_that_apply`
  - Prompt: Select the checks that belong in an integration readiness review.
- Item 4: `oli_multiple_choice`
  - Scenario: A section launch fails only in the LMS-integrated workflow. Which admin area is most relevant to inspect first?
- Item 5: `oli_short_answer`
  - Prompt: Why is it risky to consider an integration complete before downstream validation?
- Item 6: `oli_multiple_choice`
  - Prompt: Which concept best represents an admin-managed bridge between Torus and an LMS context?

Mastery signal:

- learner can reason about integration setup as an operational dependency for delivery success

## Module 3.3: Operations, Governance, and Support

### Module Goal

Teach learners the recurring operational responsibilities that help admins keep Torus reliable, governed, and supportable.

### Learning Objectives

After this module, the learner should be able to:

- identify the main operational surfaces used by admins
- distinguish section oversight, publisher/ingest workflows, and platform support concerns
- recognize basic security and governance responsibilities
- route issues to the right operational or support path

### Page Plan

#### Page 1: Section and Product Oversight

Summary:

- Show that administration often includes visibility across products and sections.
- Explain the difference between local teaching concerns and platform oversight concerns.

Key teaching points:

- admins often need cross-section visibility
- oversight surfaces help identify support and governance needs
- operational visibility is broader than individual instructor workflow

Suggested formative activity:

- Type: `oli_check_all_that_apply`
- Prompt idea: Which tasks are more aligned with platform oversight than day-to-day teaching?

Media:

- `[Screenshot placeholder: admin sections or products view]`

#### Page 2: Ingest, Publishers, and Platform Operations

Summary:

- Introduce ingest and publisher management as operational capabilities.
- Keep emphasis on what they are for and when an admin should care.

Key teaching points:

- ingest supports bringing content or data into managed workflows
- publishers and related operational tools matter to system readiness
- these surfaces usually support broader organizational workflows, not daily teaching

Suggested formative activity:

- Type: `oli_multiple_choice`
- Prompt idea: Which admin concern is most closely related to platform-wide content or publishing operations?

Media:

- `[Screenshot placeholder: publisher or ingest processing views]`

#### Page 3: Security, Performance, and Escalation Paths

Summary:

- Give administrators a lightweight operational governance framework.
- Explain that some issues are supportable locally, while others require escalation.

Key teaching points:

- admins should protect access boundaries and integration integrity
- performance and reliability concerns may require operational escalation
- good triage depends on identifying the right problem domain early

Suggested formative activity:

- Type: `oli_short_answer`
- Prompt idea: When should an administrator escalate an issue instead of trying to solve it only through account or section settings?

#### Page 4: Supporting Authors and Instructors

Summary:

- Close the unit by framing administration as an enabling function.
- Show how admins support course teams without taking over authoring or teaching roles.

Key teaching points:

- administrators support, unblock, and route
- good admin support depends on understanding role boundaries
- the best support response often starts with correct issue classification

Suggested formative activity:

- Type: `oli_ordering`
- Prompt idea: Order the support triage path from issue report to escalation or resolution.

### Module 3.3 Scored Assessment Blueprint

Title:

- Operate and Support the Platform

Assessment goal:

- verify that the learner understands platform operations, governance, and support routing

Recommended items:

- Item 1: `oli_multiple_choice`
  - Prompt: Which task is most aligned with platform oversight rather than classroom teaching?
- Item 2: `oli_check_all_that_apply`
  - Prompt: Select the issue types an administrator may need to route or escalate.
- Item 3: `oli_multiple_choice`
  - Scenario: A problem appears to affect multiple institutions or integrations. What should the admin infer first?
- Item 4: `oli_ordering`
  - Prompt: Order the basic support triage flow from report to action.
- Item 5: `oli_short_answer`
  - Prompt: Why is correct issue classification important in Torus administration?
- Item 6: `oli_multiple_choice`
  - Prompt: Which admin concern most directly protects platform trust and stability?

Mastery signal:

- learner can distinguish administrative support, operations, and escalation responsibilities

## Unit 3 Media Backlog

- `[Screenshot placeholder: users and authors admin views]`
- `[Screenshot placeholder: institutions list or institution details]`
- `[Screenshot placeholder: registrations and deployments UI]`
- `[Screenshot placeholder: external tools admin surfaces]`
- `[Screenshot placeholder: admin sections or products view]`
- `[Screenshot placeholder: ingest workflow or publisher management]`

## Administration Notes For Later MCP Work

When this unit is converted into Torus content:

- keep technical standards language light unless it directly supports an admin decision
- use scenarios that show role boundaries clearly
- favor applied judgment over memorization of labels
- make escalation questions concrete and operational

## Recommended Next Slice

The next high-value step is to convert all three units' scored assessment blueprints into explicit item stems, answer keys, and feedback notes before generating Torus activities through MCP.
