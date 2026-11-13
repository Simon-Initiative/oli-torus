# Interactives: Torus Prototype Intent

## Purpose

Create a new statically defined Torus activity type named **Interactive**. Authors place instances on course pages just as they place multiple-choice questions. Instead of configuring a predefined interaction or composing adaptive screens, the author describes a domain-specific learning experience in a prompt, selects relevant learning objective skills, and launches an agentic authoring session.

The agent creates, compiles/builds as needed, and tests software that implements the experience. It returns a bundle of static web files to Torus. Torus stores those files and renders the bundle's `index.html` in an iframe during delivery.

The activity type and its Torus authoring/delivery components are defined in the codebase. The experience inside each instance is generated software, with its own presentation, interactions, and learning tasks.

This document specifies prototype intent and phased outcomes. It is not a technical design. Codex should inspect Torus and Nimoy to determine the implementation, reuse existing conventions, and resolve integration details. API names below describe capabilities, not prescribed endpoint paths or signatures.

## What makes an Interactive a Torus learning activity

An Interactive is more than an embedded web application. Its generated code uses Torus delivery APIs throughout the learning experience to persist learner state and record measurable learning outcomes within Torus's existing activity-attempt and part-attempt hierarchy.

A part represents an opportunity for a learner to demonstrate a selected skill through an observable action. Examples include dragging the correct test tube into the correct beaker, positioning a point correctly on a Cartesian graph, or answering a French-language question correctly in French. Parts are assessment opportunities, not necessarily screens or individual clicks.

The generated experience determines how these opportunities are presented. Torus records the resulting response/content and correctness or incorrectness against the relevant part attempt and learning objective mapping. The activity can also save and restore arbitrary interaction state so the learner can return to the experience.

The number of meaningful parts is not known when the author initially selects learning objectives. The author therefore selects a set of target skills for the Interactive as a whole. The generated experience must ultimately identify its parts and their mappings to those selected skills so Torus can represent and track them. The representation and handoff of this information are implementation decisions for Codex. When an author first places one of these activities in a page, the content model must define an intial part by convention, but then once the agent has finished build the interactive the list of parts that it contains must be captured and updated in the underlying JSON model of the activity.  This is crucially important and perhaps we must define a requirement that the interactive in its ZIP bundle include not only a bootstrappable index.html but also a manifest.json that principally defines the list of parts and which objectives they pertain to (each part can target 1 or more objectives, but MUST target at least one)

## Author and learner experience

1. An author inserts an Interactive into a page using the normal activity insertion workflow.
2. Its authoring interface shows a custom multiselect for second-level learning objectives of type **SKILL**, a large prompt text area, and a **Build** button.
3. The author selects target skills, describes the desired learning experience, and clicks Build.
4. Torus launches an agentic session in a workspace capable of creating and testing client-side web software.
5. The agent receives the author prompt, selected skills, and documentation of the delivery capabilities available to its generated application.
6. The agent builds and tests the experience, then invokes a finished callback/API with a ZIP bundle and the information needed to associate the result with the activity.
7. Torus extracts the bundle, reads the manifest to update the parts listing in the activity model JSON, and stores the bundle in S3 under a new folder and preserves that location in the activity model.
8. Delivery loads the stored `index.html` in an iframe. The learner interacts with the generated experience, which uses the Torus delivery APIs as appropriate.
9. Once a successful build exists, the author can provide a follow-up prompt and use **Revise** to launch another session with the existing bundle and save an updated experience.

## Creative freedom and bundle expectations

Interactives may use vanilla JavaScript, React, Three.js, or other suitable client-side technologies. They may feature two-dimensional or three-dimensional graphics or be completely text based, and may include games, simulations, virtual labs, conversations, graphing exercises, and complex interactive questions. They are not constrained to the existing adaptive-page screen, component, or rule structures.

The delivery artifact is a ZIP of statically served web files. **`index.html` is the only required file by name** and is the iframe entry point. Other files depend on the experience: JavaScript, CSS, images, audio, models, or other client-side assets. This document does not require a particular framework, build system, manifest file, or package layout beyond that entry point.

The authoring agent must know the available delivery APIs and their intended semantics before generating the experience. Instrumentation is part of the generated software, not something added manually after generation.

Generated server-side application code is outside the initial prototype. Delivery-time AI capabilities are a possible later extension through Torus-managed APIs.

## Prototype development phases

### Phase 1 — Register the Interactive activity type and create shells

Create the new statically defined Interactive activity type that can be used on Basic pages with shell authoring and delivery components. Make instances insertable into pages through the normal Torus activity workflow.

The initial authoring component should:

- Render a custom learning objective multiselect restricted to second-level **SKILL** objectives.
- Render a large text area for the author's prompt.
- Render a **Build** button.
- Preserve the prompt and selected skills with the activity.

Do not use the default part-oriented learning objective selector: the eventual number of generated parts is not known at this stage. Initial authoring models may contain one static part to satisfy the existing activity structure.

The delivery shell initially does nothing. Build does not need to launch a session until the later integration phase.

**Phase outcome:** An author can add an Interactive, select skills, and enter a prompt. The activity has valid initial model scaffolding and registered authoring/delivery components.

#### Phase 1 implementation

- [x] Define `oli_interactive` in `assets/src/components/activities/interactive/`, with manifest-discovered authoring/delivery bundles and a registered creation function.
- [x] Add Interactive to the globally available activities in `priv/repo/seeds.exs`, making it available in the normal Basic page insertion menu after seeding.
- [x] Provide a custom skill multiselect and prompt editor; suppress the standard part-oriented objective selector only for this activity type.
- [x] Persist generation inputs in `authoring.prompt` and `authoring.selectedSkillIds` through the standard activity model update flow. Keep one placeholder part and leave its objective mappings empty until generated parts are known.
- [x] Render a disabled Build button and an empty delivery shell.

Torus currently represents learning objectives with `parentIds`, without an explicit `SKILL` discriminator. For this prototype, eligible skills are direct children of top-level objectives; top-level and deeper-only objectives are excluded. The page editor supplies its existing project objective list through the Interactive's authoring context. Generation inputs stay in the authoring portion of the model, which Torus removes from learner delivery models. No database schema changes or new persistence endpoints are needed.

Verification: three focused Jest tests exercise creation/element registration, page-editor event persistence and reload, multi-selection, and read-only behavior; TypeScript checking, targeted ESLint, formatting checks, eight existing backend manifest/model tests, and the full development Webpack build pass. The activity was also registered successfully in the local development database as globally available. Formal review remains pending until the complete prototype is implemented.

### Phase 2 — Integrate agentic sessions and a suitable workspace

Bring the Agents API wrapper from the Nimoy codebase (../agent-console) into Torus and adapt it for Interactive authoring sessions.

Provide an execution environment in which the agent can create files, use client-side development tooling, build/compile the application as needed, and test it in a browser. The environment should support producing a working web experience, not merely generating source text.

The initial direction is to investigate and use customized OpenAI-hosted environment support if it can meet the prototype's needs. This is a capability to verify during implementation, not an assumption that a particular hosted environment already supplies every required tool. A custom image/container with preinstalled tooling, including Chromium, is a likely eventual direction. Codex should determine the concrete integration based on the available environment and the existing Nimoy wrapper.  For this prototype list ONLY use OpenAI hosted sandboxes described at https://developers.openai.com/api/docs/guides/agents-api/environments/openai-hosted.    Install only minimal extra packages to enable client side web development and the ability to create the final ZIP file.

Do NOT use any of the exiting GenAI infrastructure in Torus.  Side step all of that and read and use the OPENAI_API_KEY environment variable and OPENAI_EXECUTOR_API_KEY keys if you need them.

**Phase outcome:** Torus can initiate an agentic session with a workspace suitable for creating and testing a simple client-side web experience but that isn't connected back to Torus yet.

#### Phase 2 implementation

- [x] Adapt Nimoy's `AgentConsole.Providers.OpenAI` into `Oli.Interactives.AgentsClient`, using Torus's existing HTTPoison dependency. Support session creation, session/environment inspection, saved items, latest-turn inspection, input submission, cancellation, and deletion. Keep provider pagination and sanitized error details; do not automatically retry uncertain mutations or follow redirects.
- [x] Add `Oli.Interactives.start_session/2` and a hosted-only workspace recipe. Read `OPENAI_API_KEY` directly at request time. No Torus GenAI modules, registered models, executor containers, or database schema changes are involved. `OPENAI_EXECUTOR_API_KEY` is not needed for hosted execution and is not forwarded.
- [x] Supply pinned esbuild and Playwright dependencies through inline workspace files in `priv/interactives/workspace/`. Use the hosted environment's existing Node.js and Python, install only Chromium's headless shell and its required system libraries, and use Python's standard-library `zipfile` for ZIP creation.
- [x] Gate agent startup on a setup script that compiles JavaScript, serves a tiny page over loopback HTTP, exercises a button in headless Chromium, checks browser errors, and creates/reads a ZIP. Successful setup writes `/workspace/torus-tools/ready.json`; any failure exits nonzero.
- [x] Provide `mix interactives.session` to launch and observe the prototype independently of Phoenix, the database, and Build. Retain the provider session ID for subsequent inspection and cleanup. Build, activity association, bundle return, and S3 storage remain Phase 3 work.
- [x] Complete a live hosted sandbox acceptance run using the configured OpenAI project credentials from `oli.env`.

The [hosted sandbox contract](https://developers.openai.com/api/docs/guides/agents-api/environments/openai-hosted) provides `/workspace`, inline files and ordered setup commands. The recipe uses the default-sized `medium` container with outbound networking enabled for package/browser installation. Agent source goes in `/workspace/app`; eventual deliverables go in `/workspace/outputs`. No custom image or alternate sandbox provider is configured. See the [session API](https://developers.openai.com/api/reference/resources/beta/subresources/agents/subresources/sessions/methods/create) for the request contract.

Load the local environment without printing credentials, then run:

```sh
set -a
source oli.env
set +a
mix interactives.session --smoke --wait
mix interactives.session --session SESSION_ID --wait
mix interactives.session --session SESSION_ID --cancel
mix interactives.session --session SESSION_ID --delete
```

The smoke prompt asks the agent to build, browser-test, and ZIP a counter application entirely inside the hosted sandbox. Creation returns before setup finishes; readiness requires the environment to be `connected`, and completion requires the latest turn to be `completed`. `--timeout` defaults to 900 seconds; a timeout leaves remote work intact, so inspect or cancel the same session instead of launching another. Cancel active work before deleting its session. `--prompt` supplies a custom task, and `--model` overrides `INTERACTIVES_MODEL` (default `gpt-6-astra`).

Verification: four focused ExUnit tests pass for the HTTP contract, hosted recipe, credential isolation, request failures, pagination, input, cancellation, and cleanup. Compilation with warnings treated as errors and formatting checks pass. After sourcing `oli.env`, live session `sess_0ddcea7ec0213f00006af5f75482e48196af185f36ffe3b93d` reached environment `connected` and turn `completed`. Hosted setup passed with Node 22.23.3, esbuild 0.25.12, Playwright 1.56.1, and Chromium 141.0.7390.37. The agent built a counter, browser-tested `0 → 1 → 2` over loopback HTTP without browser errors, and created a 1,297-byte ZIP containing `index.html`, `styles.css`, and `bundle.js` at its root. Independent download and inspection confirmed ZIP integrity and asset references. The completed session was deleted to request sandbox cleanup. No callback or storage integration was added. Phase 2 acceptance is complete; formal review remains pending for the complete prototype.

### Phase 3 — Connect Build to generation, bundling, and return to Torus

Connect the authoring Build action to the agentic session. Supply the author prompt and selected skills, and initially ask the agent to create a simple working experience.

The agent should create the application, build it where necessary, test it, and package its deliverable as a ZIP. When finished, it should call a Torus finished API/callback with that ZIP or the means for Torus to receive it.

Torus should unzip the returned files and upload them into an S3 bucket under a new folder name. Preserve the folder/location in the activity model so delivery can locate the result. The completion handoff must associate the output with the correct authoring activity instance.  Use the S3 S3_MEDIA_BUCKET_NAME bucket.  Under that bucket, create a /interactives folder and then the generated folder names under that folder so we have <bucket>/interactives/<some generated guid>/index.html and other files as siblings or even sub dirs.

The exact callback mechanism, transfer details, model fields, and bundle processing are left to codebase-informed implementation. Parameterize the model to use from within a simple dropdown in authoring UI and include Astra, Sol and provide a way to adjust reasoning level.

**Phase outcome:** An author can click Build and obtain an agent-built, tested web bundle stored in S3 and referenced by the activity model. Full learning instrumentation follows in Phase 5.

#### Phase 3 implementation

- [x] Connect Build to author-authenticated creation/status endpoints, save generation inputs through the existing activity editor, and queue a durable `interactive_builds` record with an Oban worker. Only one build per project/activity may be active.
- [x] Save Astra/Sol and Low/Medium/High reasoning choices with the activity. Send the selected model/effort, prompt, and server-resolved project skill IDs/titles into the hosted session.
- [x] Expose the narrow `finish_interactive` Agents function. The agent writes `/workspace/outputs/interactive.zip`, invokes the function, receives Torus's acknowledgement, and ends its turn. Torus then retrieves the published artifact for that exact session/turn; no public callback URL or sandbox credentials are needed.
- [x] Require a root `index.html` and a version 1 `manifest.json` describing actual parts: `{"version":1,"parts":[{"id":"part_1","objectiveIds":[123]}]}`. This makes the earlier generated-part handoff requirement concrete. Each part needs a unique ID and one or more selected skill IDs. ZIP paths and resource limits are checked before extraction into memory.
- [x] Upload the extracted files, with MIME types and encryption, under `interactives/<build UUID>/` in the configured `S3_MEDIA_BUCKET_NAME`. Store `bundle: {buildId, bucket, prefix, indexUrl}` in the activity model, replace the placeholder parts, and save corresponding revision objective mappings together through the existing authoring locks/revision path. Reject stale generation inputs and active conflicting locks. Completion can safely reacquire a released lock after the browser closes.
- [x] Show progress/failure/completion in authoring and resume observation after reload. Apply canonical model and objective updates together, preserving a previous successful bundle if another build fails. Session creation is never automatically repeated after an ambiguous request, builds have a 30-minute deadline, and completed sessions are deleted.

The implementation plan and boundary decisions are in [plan.md](plan.md). Iframe delivery, preview, learning APIs, and prompt-driven revision remain in their later phases.

Verification: eight focused backend tests and five frontend tests pass; TypeScript, targeted ESLint, formatting, compilation with warnings treated as errors, and the full development asset build pass. The new migration passed up/down/up on the local database without applying an unrelated pending migration. A real Basic-page browser session selected Sol/low, saved and reloaded the inputs, clicked Build, reloaded during generation, and observed saved completion after another reload. Live build `e3b9fd6b-4c32-4650-80a6-ca4f4f46c4b8` for activity `21` in acceptance project `example_open_and_free_course_7teki` completed its function handoff and stored files under `torus-media-dev/interactives/e3b9fd6b-4c32-4650-80a6-ca4f4f46c4b8/`. Independent S3 reads confirmed `index.html`, the manifest's `part_1 → skill 19` mapping, and the matching persisted activity parts/objectives; the public entry returned HTTP 200. The provider session was deleted (subsequent retrieval returned HTTP 404). Phase 3 acceptance is complete. Formal review remains deferred until the complete prototype.

### Phase 4 — Render the generated experience in delivery

Update the delivery component to read the stored bundle location from the activity model and render an iframe loading that bundle's `index.html`.

The generated experience and its assets should load and be usable from the Torus page. Determine the appropriate embedding and isolation details from the application context; this document does not prescribe their implementation.

**Phase outcome:** A learner can open a page containing the Interactive and use the generated web experience inside Torus.

#### Phase 4 implementation

- [x] Render the persisted `bundle.indexUrl` from the normal delivery web component, using the learner's pruned activity model. Unbuilt/invalid bundle locations show an unavailable message.
- [x] Use a full-width iframe with a native 576px default height, an accessible title, normal internal scrolling, and no parent referrer. The native height avoids falling back to the browser's 150px default when existing CSS assets do not contain a new utility class.
- [x] Enable scripts in a sandbox, preserving the media origin only when it differs from the Torus origin so module scripts and asset fetches can work. Same-origin bundles retain an opaque sandbox origin. No forms, popups, top navigation, or extra browser permissions are granted. See the [iframe sandbox contract](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/iframe#sandbox).
- [x] Publish the existing generated example, deploy it to a section, enroll a learner, and verify real delivery interactions and asset loading after reload.

Verification: twelve focused frontend tests pass, together with TypeScript checking, targeted ESLint, formatting, and the full development Webpack build. Browser acceptance used section `interactive_phase_4_acceptance` (ID `3`), enrolled learner `3`, and activity `21`, published from the Phase 3 acceptance project. The generated S3 HTML, CSS, and JavaScript each returned HTTP 200 inside the iframe. Incorrect/correct answer feedback worked before and after reloading the learner page. The delivery model contained no authoring data; browser checks confirmed blocked access to the parent document and an empty referrer. The iframe rendered at 576px high and 358px wide in a 390px viewport. Screenshot inspection confirmed the full exercise was visible at the default height. No bundle rebuild, backend schema change, or new delivery API was required.

Phase 4 acceptance is complete. Height auto-sizing, learner-state/grading integration, authoring preview, and prompt-driven revision remain outside this phase. Formal review remains deferred until the complete prototype.

### Phase 5 — Add basic Torus delivery API integration

Define and expose the basic capabilities below, then give the authoring agent sufficient documentation and context to incorporate their use into generated experiences.

| Capability | Intended behavior |
| --- | --- |
| activity attempt scoped Key-value state read | Restore named values from the current activity attempt's `state` JSONB field. |
| activity attempt scoped Key-value state write | Save named values into that same activity-attempt state for later restoration. |
| course section scoped Key-value state read | Restore named values from the current student enrollment `state` JSONB field. |
| course section scoped Key-value state write | Save named values into the current student enrollment state for later restoration. |
| Part-attempt finalization | Record a measurable response/action, its response content or result data, and correctness/incorrectness, analogous to existing client-side evaluation. |
| Overall activity finalization | Complete the activity attempt in accordance with Torus's activity lifecycle. |

Both the attempt scoped and section state capability is intended to map directly to the existing activity-attempt `state` JSONB field and enrollment `state` rather than introduce an unrelated persistence concept. And there are already higher level context you can use to read and write, you do not need to write that impl yourself.

At this phase, move beyond the single placeholder part where necessary. The generated experience must provide enough information about its actual parts and their selected-skill mappings for Torus to create and manage the corresponding attempts. Determine how this fits the existing activity model, evaluation, reset, and delivery lifecycle by inspecting the codebase. A good pattern to follow would be to assume that intially
all part attempts are created as "active" when the activity is first instantiated, that is how Torus works. Then, as the delivery impl uses the part attempt finalziation to record what a student has done that impl of that API will mark that part attempt as "evaluated".  This API can be called again for the same part, it is up to that impemetnat and its context to determine if that is a sensible thing to do.  But interally that API has to see and check that the most recent part attempt for that part is alredy "evaluated", so interally it would first have to create a new part attempt record and then finalize that.  With this impl, we avoid having to expose to to the Interactive both a "finalize" and "reset attempt" API - we just have a singular "finalize" that internally will reset to creat a new part attempt record when needed.

Generated experiences should use these capabilities at meaningful points: restore state when resuming, save progress as appropriate, finalize a part when the learner commits a measurable action, and complete the activity when its learning tasks are finished.

THis is a prototype but focus on producign a VERY VERY VERY clean interface for this Delivery API, one that will be straightforward to expand on in the future.

**Phase outcome:** A generated Interactive can save and restore a learner's state, record correct and incorrect part results with response content and objective mappings, support retries, and finalize its activity attempt through Torus.

Phase 5 implementation is complete. A versioned `TorusInteractive.connect()` SDK exposes `attempt.get/set`, `section.get/set`, `parts.finalize`, and `activity.finalize` through a source/origin-checked parent bridge and an authenticated learner endpoint. The repository had state on page attempts, so the implementation adds the required JSONB field to actual activity attempts and extends `Oli.Delivery.ExtrinsicState`; enrollment state uses the existing section-state context. Part finalization reuses Torus reset/client-evaluation behavior internally; explicit completion uses its scoring/progress rollup. Generated manifest parts retain their selected-skill mappings.

Verification: eleven focused backend tests, sixteen frontend tests, types, lint, formatting, compilation, asset build, and migration up/down/up pass. A newly generated two-part bundle completed a real authoring → publication → enrollment → learner flow. Incorrect and correct retries produced four evaluated part attempts and objective analytics of four attempts/two correct; explicit completion scored 2/2. Activity/enrollment state survived reload, completed work restored read-only, and existing Reset Answers cleared only the activity-attempt scope. Detailed boundaries and evidence are in `docs/exec-plans/current/interactives/plan.md`; the agent-facing API contract is `priv/interactives/skills/references/delivery-api.md`. Phase 6 and formal final review remain pending.

### Phase 6 — Support authoring preview and prompt-driven revision

Ensure the authoring page preview correctly renders a built Interactive. Preview should allow authors to inspect and try the experience using Torus's appropriate preview behavior.

Once an initial build has completed, replace the **Build** action with **Revise**. The author supplies a new prompt describing changes. Revise launches another agentic session with the existing bundle and the new instructions so the agent can modify the current experience rather than recreate it without context.  The original prompt is permanently stored, and every "revision" prompt gets stored in the activity model under a "revision_prompts" list.  A dropdown can allow the author to view read only original prompt and read only previous revision prompts.

The agent should test its changes and return the updated bundle through the completion workflow. Torus saves the updated experience and makes it available to authoring preview and delivery through the applicable authoring/publication behavior.

The intended outcome is iterative editing: for example, “make the graphing task harder,” “add feedback for this misconception,” or “change the lab to use a different target concentration.” Determine the specific retention of editable materials and revision mechanics from the implementation needs; no source-storage or versioning design is prescribed here.

**Phase outcome:** An author can preview an Interactive, request changes through a follow-up prompt, and preview/use the resulting revision.

Phase 6 implementation is complete. Built activities expose **Revise**, a separate revision draft, and a read-only selector for the original prompt and ordered `authoring.revision_prompts`. Each accepted revision request is recorded; successful completion clears the draft. Revision sessions load the current completed bundle's validated files into `/workspace/app` before the agent modifies them. Completion uses the existing callback, bundling, authoring-lock and versioning paths, preserving the previous bundle on failure.

Both inline author preview (with Restart preview) and the normal author page Preview route render the generated app through the same SDK contract with temporary browser state. No learner/enrollment state is written. A live revision changed the example's heading and feedback while preserving both task IDs and selected-skill mappings. Its original prompt/history survived reload, the revised preview worked, and publication to a fresh section delivered the revision while the existing section retained its previous bundle. The revised learner flow again verified persistence, retries, objective-linked results, and explicit 2/2 completion.

Final verification: thirteen focused backend tests and eighteen frontend tests, TypeScript, lint, formatting, compilation, and the complete development asset build pass. Independent security, performance, Elixir, UI, and TypeScript reviews covered the complete prototype. The one UI finding (announcing asynchronous build status) is fixed; no unresolved findings remain. Detailed evidence and prototype limits are recorded in `docs/exec-plans/current/interactives/plan.md`. All six phases are complete.

Authoring guidance is now packaged as two hosted skills: `priv/interactives/skills/build-interactive/SKILL.md` and `priv/interactives/skills/revise-interactive/SKILL.md`. Both include platform context and require shared SDK and authoring-contract references; these define meaningful state/evaluation use, browser testing, ZIP packaging, and `finish_interactive` handoff. Build guidance covers client-side technology selection; revision guidance focuses on precise edits to the existing app. Separate thin system instructions require the matching skill. The revision task includes the original request, ordered prior requests, and a distinct current request. All skill/reference files are supplied in the session environment. Refinement verification passed sixteen focused backend tests, both skill validators, compilation, and formatting.

Authoring now includes live session monitoring for both Build and Revise. The active prompt shrinks and becomes selectable/read-only above a contrasting dark monospace output pane. The pane restores recent saved output and reconnects to live events after navigation or network interruption. Cancel session durably fences completion, stops/deletes the provider session, then hides the console and restores the full editable draft. The last successful bundle is retained on cancellation. Completed/failed transcripts are retained for inspection; output is bounded and excludes internal reasoning and input-message records. Verification passed twenty-five backend tests, twenty-one frontend tests, types/lint/format/compile/assets, migration up/down/up, and real Build/Revise reload/cancel flows. Targeted specialist reviews have no unresolved findings. See `docs/exec-plans/current/interactives/plan.md` for evidence.

## Potential delivery-time AI extension

Later, Interactives may access Torus-managed LLM/AI endpoints for generating content and making decisions, such as capabilities corresponding to the Completions API and Decisions API. These are delivery-time calls, separate from the agentic sessions that author the software.

Examples include a French-speaking shopkeeper that responds dynamically to the learner, a virtual patient that answers interview questions, or a lab coach that generates guidance based on the current experiment state. The generated application would invoke the available Torus capability at appropriate moments in its interaction flow.

This is likely outside the initial prototype. Keep it as an extension of the delivery API concept, without making live AI calls a requirement for an Interactive to function. The endpoint contracts and any relationship to evaluation remain future design work.

## Example experiences across domains

These illustrate the intended breadth and creative freedom; they are not requirements to implement all examples in the prototype.

1. **Chemistry:** Mix stock solutions in a virtual lab to achieve a target concentration, with feedback on calculations and technique.
2. **Machine learning:** Adjust a classifier's decision boundary and explore how model complexity affects training error and generalization.
3. **Physics:** Build a roller coaster that satisfies energy, acceleration, and passenger safety constraints.
4. **Biology:** Modify a virtual cell's environment and predict how changes affect transport across its membrane.
5. **Statistics:** Design a sampling strategy for a simulated population and investigate bias and confidence interval coverage.
6. **Economics:** Manage a city's housing policies and observe how supply, demand, taxes, and rent controls affect its residents.
7. **Computer networking:** Diagnose a broken network by inspecting packets, testing connectivity, and correcting routing configurations.
8. **Cybersecurity:** Investigate a simulated intrusion by correlating logs, identifying the attack path, and selecting containment actions.
9. **Mathematics:** Plot points and manipulate curves on a Cartesian graph to satisfy equations or constraints on slope, continuity, and clearance, potentially within a bridge-building game.
10. **Astronomy:** Manipulate a three-dimensional Sun–Earth–Moon model to reproduce observed lunar phases and eclipses.
11. **Environmental science:** Restore a watershed by balancing agricultural practices, runoff controls, biodiversity, and budget.
12. **Medicine:** Work through a virtual patient encounter, choosing questions and tests to distinguish competing diagnoses.
13. **Nursing:** Prioritize care for several simulated patients as vital signs change and new information arrives.
14. **Civil engineering:** Design a truss bridge and stress-test it under different loads to identify structural weaknesses.
15. **Electrical engineering:** Assemble and troubleshoot a circuit using a virtual multimeter and oscilloscope.
16. **History:** Reconstruct an event from conflicting primary sources, weighing provenance, chronology, and corroborating evidence.
17. **Foreign languages:** Navigate an interactive marketplace by listening to vendors, answering questions in French, and negotiating purchases; later, live AI could drive the dialogue.
18. **Music theory:** Build chord progressions and resolve harmonic tensions in an interactive composition workspace.
19. **Accounting:** Investigate a fictional company's transactions, correct journal entries, and reconcile its financial statements.
20. **Privacy engineering:** Redesign a fictional app's data flows to meet functional requirements while minimizing collection and limiting access.

## Prototype success

The prototype succeeds when an author can place an Interactive on a page, select target skills, describe an experience, and obtain a working agent-built application rendered within Torus. That application must demonstrate meaningful integration with learner state and objective-linked part results. The author must then be able to preview it and revise it with another prompt.

The goal is to prove this complete authoring-to-delivery workflow with a small number of compelling examples. It does not require a comprehensive adaptive-page authoring API, a new visual editor, generated server-side execution, or delivery-time AI in the first iteration. Detailed architecture and implementation choices belong to Codex working with the actual Torus and Nimoy codebases.
