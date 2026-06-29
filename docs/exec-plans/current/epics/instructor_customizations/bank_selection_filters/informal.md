# Bank Selection Filters - Informal Notes

Source: Jira `MER-5624` read with `acli jira workitem view MER-5624` on 2026-06-29.

## Jira Summary

- Key: `MER-5624`
- Type: Story
- Status at capture time: In Progress
- Epic context: `instructor_customizations`
- Title: Filter Questions within Activity Bank Selection

## User Story

As an instructor, I want to filter questions within an Activity Bank Selection, so that I can efficiently manage large question pools and quickly find relevant questions.

## Acceptance Criteria Summary

### Primary Visibility Filters

- In the Activity Bank Selection management view, display a primary single-select filter group above the question table.
- Primary options:
  - Show All
  - Show Available
  - Show Removed
- Default state is Show All.
- Show Available displays only available questions.
- Show Removed displays only removed questions.
- Show All displays both available and removed questions.
- Only one primary filter can be active at a time.

### Secondary Filters

- Display a second filter layer with:
  - Search
  - Learning Objectives
  - Question Type
- Reuse the search and filter component from instructor insights where practical.

### Search

- Search updates table results dynamically as the user types.
- Search should match question title and question content where applicable.
- Search should not require manual submission.

### Learning Objective Filter

- Users can multi-select learning objectives.
- Options are generated dynamically from learning objectives attached to questions in the current Activity Bank Selection table, including both removed and available rows.
- Selecting one or more objectives narrows the table to matching questions.

### Question Type Filter

- Users can multi-select question types.
- Options are generated dynamically from question types present in the current Activity Bank Selection table, including both removed and available rows.
- Selecting one or more question types narrows the table to matching questions.

### Combined Filtering

- Filters combine to narrow results.
- Example combined state:
  - Show Available
  - Learning Objective filter
  - Question Type filter
  - Search text
- Results should match all active filter criteria.

### Clear All Filters

- Clear All Filters clears secondary filters.
- Search input is cleared.
- Primary visibility resets to Show All.
- Table returns to the default unfiltered state.

### Table State Updates

- Table updates dynamically without a page refresh.
- Empty result sets show explanatory messaging, for example: "No questions match the selected filters."

## Negative Acceptance Criteria

- Do not allow Show All, Show Available, and Show Removed to be selected simultaneously.
- Do not display learning objectives that are not attached to questions in the current Activity Bank Selection table.
- Do not display question types that are not present in the current Activity Bank Selection table.
- Do not return removed questions when Show Available is active.
- Do not return available questions when Show Removed is active.
- Do not require manual submission for search filtering.
- Do not clear active filters unintentionally during table interactions.
- Do not reset filters during:
  - remove actions
  - restore actions
  - bulk actions
  - question preview interactions
- Do not display an empty table without explanatory messaging.

## Design References

- Filter toolbar: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=305-11129`
- In-page context: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=185-7391`
- Full filter component, including Show All/Available/Removed toggles plus search, learning-objective filter, and question-type filter: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=185-7440&t=SNzWnAHAxamIxKZQ-4`
- Search bar plus learning-objective and question-type filter component detail: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=305-11129&t=SNzWnAHAxamIxKZQ-4`
- Learning Objectives dropdown example: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=385-6445&t=SNzWnAHAxamIxKZQ-4`

## Local Context

- The epic plan lists `MER-5624` under the Selection-UI lane after `MER-5622` and `MER-5623`.
- `docs/exec-plans/current/epics/instructor_customizations/bank_selection_manager/prd.md` explicitly excludes search, learning-objective filters, and question-type filters from `MER-5622`.
- `docs/exec-plans/current/epics/instructor_customizations/bank_selection_manager/fdd.md` says `MER-5623` and `MER-5624` should extend the same bank-selection manager LiveView rather than replace it.
