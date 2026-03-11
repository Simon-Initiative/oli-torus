# Quality Score

## Current State

Overall quality score: Medium.

Reasons this is not low:

- Torus has a large existing automated test base, including roughly thousands of unit and integration tests across Elixir, TypeScript, LiveView, and `Oli.Scenarios`
- the repository has strong coverage for many isolated behaviors and a meaningful amount of backend workflow testing
- the project has clear testing conventions and multiple available test layers

Reasons this is not high:

- there are still important automation gaps around LTI launch behavior
- grade passback coverage is not yet strong enough for the importance of that integration boundary
- some key authoring flows still lack enough high-confidence automated end-to-end or scenario-based coverage
- critical cross-system workflows remain more exposed to regression risk than the raw test count suggests

## What Would Raise The Score

- stronger automated coverage for LTI launches and related LMS integration paths
- stronger automated coverage for grade passback and reporting behavior
- better automated coverage for the most important authoring workflows
- continued expansion of scenario and browser-level coverage where workflow integration risk is highest
