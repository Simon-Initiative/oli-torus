# MER-4945 - adaptive_triggers

## Jira Description

Currently, there are no activation points available for adaptive pages. As a first step toward parity with basic pages, we want to introduce **screen-level AI Activation Points** within adaptive lessons. These should function similarly to **Page Activation Points** and **Paragraph Activation Points** on basic pages, but implemented as a new component specific to adaptive pages.

This new **AI Activation Point component** will offer authors two configuration options:

1. **Auto Activated** - DOT pops up automatically when the screen is loaded.
2. **User Activated** - DOT is triggered only when the learner clicks a button or icon.

This new component should be independently placeable on any screen and configurable within the authoring UI.

## User Stories

**As an author:**

* I want to be able to add an AI Activation Point to a screen in an adaptive page, so I can control where and how DOT appears.
* I want to configure whether DOT shows up automatically or only after the student clicks something.
* I want to be able to add in my prompt

**As a student:**

* I want to see an AI prompt automatically when starting a screen (if configured).
* I want to optionally click to activate DOT when I need help or more guidance.

## Acceptance Criteria

### Positive Acceptance Criteria

* Given AI Activation Points are **enabled in the project settings**
    * When the author opens an adaptive screen in the editor
        * Then they can insert a new component called **AI Activation Point**

* Given the component is added
    * When the author selects the configuration option
        * Then they can choose between:
            * **Auto Activated**
            * **User Activated**

* Given a learner views a screen with an AI Activation Point
    * When the screen loads and the component is set to **auto activated**
        * Then DOT opens automatically

* Given a learner views a screen with an AI Activation Point
    * When the component is set to **user activated**
        * Then the learner sees a clickable icon/button that opens DOT

### Negative Acceptance Criteria

* Given AI Activation Points are **disabled in the project settings**
    * When an author edits an adaptive screen
        * Then the AI Activation Point component is not available

* Given an adaptive screen has **no activation point added**
    * When a learner views the screen
        * Then DOT does not launch automatically or appear as clickable

* Given an adaptive screen has an **activation point added but the course section has activation points disabled**
    * When a learner views the screen
        * Then DOT does not launch automatically or appear as clickable

## Design Notes

* This component mirrors functionality already present in Basic Page AI Activation Points.
* Default visual behavior (e.g., icon, hover text) should match the existing UI patterns.
* [Figma Preview](https://www.figma.com/proto/YAizhCWOW3wJjEJDSyYNXp/MER-4945-Screen-Level-AI-Activation-Points-for-Adaptive-Pages?node-id=9-38&t=UBjuYzFsu4iD6i2N-0&scaling=min-zoom&content-scaling=fixed&page-id=0%3A1&starting-point-node-id=9%3A38)
* [Figma Dev](https://www.figma.com/design/YAizhCWOW3wJjEJDSyYNXp/MER-4945-Screen-Level-AI-Activation-Points-for-Adaptive-Pages?node-id=0-1&t=UBjuYzFsu4iD6i2N-0)

## Technical Notes

* This component should be implemented as part of the **adaptive component library**, distinct from basic page components.
* Configuration should include an enum/string for launch type:
    * `launch_mode: 'auto' | 'click'`

## Darren Siegel Technical Guidance Comment

Technical guidance:

This is a FEATURE. slug: adaptive_triggers

- The clickable component should be implemented as part of the **adaptive component library**, distinct from basic page components.
- Configuration should include an enum/string for launch type:
  - `launch_mode: 'auto' | 'click'`

Similar to the trigger implementation in basic pages, we need a mechanism that checks for a page level adaptive trigger on page visit and fires the AI trigger. For the clickable AI trigger we must extend existing part components to allow an image and button part components, when clicked, to trigger the AI activation. In the authoring UI this means a checkbox for "Enable AI Activation point" along with a text input for "AI activation prompt". These will be two new attributes on these two existing part components. At Adaptive page delivery, when these components are clicked the trigger is emitted (when one is set). The adaptive page will use the same client-side API that is currently being used for basic page components that fire triggers.
