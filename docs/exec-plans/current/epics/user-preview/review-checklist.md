# User Preview ticket review checklist

Review scope: MER-6158 and its 11 Stories (including closed MER-6219) and 20 sub-tasks. This checklist tracks corrections to ticket definitions, not implementation of the feature.

## Working process

1. Refresh the existing ticket documents from current Jira details and commit the baseline. Keep one canonical document per ticket in `tickets/`.
2. Work through the remaining findings below in order. Prepare one finding's proposed changes locally, leaving them uncommitted and Jira unchanged.
3. Present the specific changes and request operator approval. If modifications are requested, revise the same draft before proceeding.
4. After approval, update Jira from the approved documents, read back and verify the descriptions, formatting, images, hierarchy, and links. Commit the approved documents and this checklist. If publication or verification fails, keep the item incomplete and report the issue.
5. Proceed to the next finding. Do not push repository commits.

## Findings

- [x] **1. Remove the backward acceptance dependency.** MER-6224 owns bank-management header/selector suppression, local back navigation, and restoration of the containing page and focus. MER-6212 owns explanatory notes. Approved and verified in Jira; included in the baseline commit.
- [x] **2. Clarify session preservation.** MER-6236, MER-6241, and MER-6226 must distinguish the authenticated account from the user used for preview requests. Identify a credible delivery boundary and verification for simultaneous learner and preview tabs. Preserve the approved tab-close exit behavior.
- [x] **3. Define recovery when update-job history is missing.** MER-6235–MER-6237 must distinguish an update in progress from a stale preview with no live update, including pruned or cancelled job records. Ensure recovery remains available without requiring unnecessary infrastructure.
- [x] **4. Define the Updating experience.** MER-6236, MER-6238, and MER-6239 use a shared readiness LiveView in the preview tab, with automatic status updates and redirect to Learn when ready. No Check Again button; retain failed-state recovery and exit.
- [x] **5. Give sub-tasks distinct completion boundaries.** Narrow duplicated whole-feature specifications in MER-6225/6226, MER-6229/6230, MER-6232/6233, and MER-6235/6236/6237. Keep common requirements in their parent Stories and retain each sub-task's relevant technical detail and acceptance checks.
- [x] **6. Correct stale identity-integration ownership.** MER-6235–MER-6238 must identify MER-6220 as the reusable account resolver/reset owner and MER-6241 as the project preview integration owner. Reconcile other occurrences of the same stale ownership.
- [x] **7. Separate bank-note and gating-note completion.** Clarify MER-6212's note presentation/bank usage and MER-6213's gating integration so neither duplicates the other's delivery commitment.
- [x] **8. Resolve MER-6221's tracking role.** Its implementation is already assigned elsewhere. Propose retaining it explicitly as a tracking Story or treating classification as a shared requirement, without inventing extra work. Obtain approval before changing its disposition.
- [x] **9. Remove drafting residue and restore incomplete policy text.** Replace MER-6215's unresolved broader-redesign question with the settled scope. Restore explicit retained-attempt behavior in MER-6236–MER-6239 and any other occurrences of the same damaged wording.
- [x] **10. Simplify technical guidance.** Remove repeated analysis/process prose and define unclear terms through concrete components, actors, actions, and outcomes. Preserve useful code pointers, design sources, required behavior, and provisional implementation choices.

## Current item

Findings 1–10 are approved and verified in Jira. All 31 ticket descriptions use the approved concise guidance; Story product/UX requirements remain unchanged. Regular instructors retain their logged-in user in both views. Admin-owned preview users receive instructor enrollment, regular authors receive student/learner enrollment, and promotion upgrades the existing preview user's enrollments while preserving identity and progress. Sub-task titles and epic/traceability references match the final ticket set.

Read-back checks confirmed exact description text, headings, paragraphs, nested lists, code formatting, links, all 17 screenshots, unchanged statuses and parent relationships, 21 Relates links, and 21 acyclic Blocks links with no cross-Story sub-task dependencies. MER-6219 and MER-6221 remain Closed Won’t Do. Independent security, performance, and UI fidelity reviews found no material omissions. Repository changes are committed locally without pushing; implementation and runtime verification remain future work.

## Completion checks

- [x] Each approved change is committed locally and verified in Jira.
- [x] Epic coverage and feature traceability match the final ticket ownership.
- [x] Story and sub-task dependencies remain acyclic, with no cross-Story sub-task dependency links.
- [x] No repository commits have been pushed.
