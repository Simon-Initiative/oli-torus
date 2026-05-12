# MER-4946 - trap_state_triggers

## Jira Description

When authoring adaptive lessons using **Advanced Author**, we want to allow authors to **trigger DOT** when a learner reaches a specific **trap state** (e.g., incorrect or correct responses).

This will be implemented by enabling authors to insert a **new action** into the **Rules Editor** for a trap state. This action will be called **"Activation Point"**, and will behave similarly to **mutate state** or **show feedback**.

When selected, the **Activation Point** action will:

* Allow the author to enter a **custom prompt** to pass to DOT
* Activate DOT in the learner interface when the trap state is triggered
* Only fire once the trap state's conditions are met

The prompt interface will mirror the Activation Point component on Basic pages, but will require new UI design for how this fits into the Rules Editor.

---

## User Stories

**As an author:**

* I want to insert a DOT activation point as an action in a trap state so I can provide targeted AI support based on student performance.
* I want to write a specific prompt that DOT will use when activated in that trap state.

**As a student:**

* I want to receive context-aware support from DOT after I trigger a specific trap state (e.g., incorrect answer).
* I want the AI to respond directly to the mistake I just made.

---

## Acceptance Criteria

### Positive Acceptance Criteria

* Given the author is editing a trap state in the Rules Editor
    * When they click the blue "+" to add a new action
        * Then they see a new option labeled **"Activation Point"**

* Given the author selects "Activation Point"
    * When the UI opens
        * Then they can enter a **custom prompt** for DOT
        * Then they can save the action and see it listed in the rule

* Given a student triggers a trap state with an Activation Point
    * When the trap state activates
        * Then **DOT opens automatically** and displays a response based on the configured prompt

### Negative Acceptance Criteria

* Given no Activation Point is added to a trap state
    * When the student triggers the trap state
        * Then DOT does not activate automatically

* Given the project has **AI Activation Points disabled**
    * When the author edits the Rules Editor
        * Then the **"Activation Point"** action is not available

* Given a **course section** has **AI Activation Points disabled**
    * When the student triggers the trap state
        * Then DOT does not activate automatically

## Darren Siegel Technical Guidance Comment

Additional technical guidance:

This is a FEATURE. slug: trap_state_triggers

The requirements are already well captured in the Description of this ticket, but we need to track down clear examples of the current JSON structure of the trap state portion of an activity content. Then propose a sound extension for including an AI activation point (aka "trigger") to it. Give examples to spec_analyze.

This is then very likely a server side emitting of the trigger from the "evaluate_activity" and the specialized path where the adaptive rules engine is fired to see which trap state gets hit. Other code in this evaluate already emits triggers for basic page activity evaluation.
