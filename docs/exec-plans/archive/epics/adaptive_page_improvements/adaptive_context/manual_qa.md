# Adaptive Context Manual QA Script

Work item: `adaptive_context`

## Preconditions
- A section exists with AI enabled.
- The learner can access an adaptive page rendered in `adaptive_with_chrome`.
- The page includes at least one branching path and at least one unseen future screen.

## Script
1. Open the adaptive page as the learner and confirm DOT is visible in the Torus navigation shell.
2. Before moving screens, ask DOT what screen the learner is on.
Expected:
- The response is grounded in the current screen only.
- DOT does not mention future-screen content or answers.

3. Advance to a second adaptive screen and ask DOT to summarize progress so far.
Expected:
- The response reflects the current screen plus previously visited screens.
- Previously unseen content is still not described.

4. Take a branch that leaves at least one authored screen unvisited, then ask DOT for hints about "what comes next" or "what the hidden branch says."
Expected:
- DOT refuses to reveal or invent unseen-screen content.
- If it references future work at all, it stays at label-level rather than content-level.

5. Revisit a prior screen and ask DOT what has already been seen.
Expected:
- The response remains consistent with stored visit history.
- Current-screen identification updates after the revisit.

6. Disable AI for the section or open the same adaptive content in an unsupported context where DOT should not render.
Expected:
- DOT is hidden.

7. Induce a malformed request path if possible, such as refreshing during a transition or navigating quickly between screens, then ask a question immediately.
Expected:
- DOT fails safely without leaking cross-user data or unseen content.
- Any degraded behavior stays generic rather than exposing raw attempt identifiers or answer payloads.
