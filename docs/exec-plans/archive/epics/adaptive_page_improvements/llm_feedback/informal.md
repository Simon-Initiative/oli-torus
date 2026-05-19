# MER-4961 - llm_feedback

## Jira Description

We want to allow authors to use an LLM to generate dynamic, personalized feedback in adaptive pages, based specifically on the student's submitted response. Unlike DOT, this feedback will not appear in the chat interface, but instead auto-populate into the default feedback box in the adaptive page.

This should function as a new component in the "Show Feedback" trap state action in the Rules Editor.

### Key Behavior

* Authors select Show Feedback via the blue "+" icon in the Rules Editor for a trap state.
* The author can select the DOT Activation Point Icon.
* The author can enter a **custom prompt** that will be sent to the LLM along with the student's response.
* The LLM returns **context-specific feedback**, which is inserted into the **standard feedback popup**.
* This feature is visible to the learner as "AI-generated".

### MVP Scope

* Only supports the following input components for now:
    * **Text Input**
    * **Multiline Text Input**
* The LLM **must have access to the actual student response** to generate relevant feedback.
* The LLM must have access to the information on the screen.

## User Stories

**As an author:**

* I want to generate context-aware feedback using AI based on what the student actually typed.
* I want to add a custom prompt that guides how the AI responds.
* I want the AI-generated message to appear in the standard feedback popup, not in DOT.

**As a student:**

* I want to receive feedback that directly relates to what I entered.
* I want the feedback to appear normally, without requiring me to use DOT or chat tools.

## Darren Siegel Technical Guidance Comment

Technical Guidance:

This is a FEATURE. Slug: llm_feedback

This feature has a strict dependence on the trap_state_triggers feature (MER-4946). We want that feature to finish and land first. It provides the waypointing in the server side evaluation code for where this feature will invoke the GenAI completions service to generate feedback.

There is Adaptive Authoring work here of course to allow the author to create an AI activation point of subtype "Generate Feedback". Capture this as a specific new attribute like `kind: feedback` on the trigger / trap state object.

Then, in the server side evaluation codepath, when we encounter that a hit trap state is an AI activation point, check for `kind: feedback`. If it is, synchronously invoke `generate` on the GenAI Completions service (via Execute) giving it the activity screen content, student response and author prompt. Return that response in the appropriate vehicle so that it gets displayed as feedback in the adaptive page delivery UI.
