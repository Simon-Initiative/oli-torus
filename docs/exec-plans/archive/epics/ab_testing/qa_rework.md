# A/B Testing QA Rework

## Purpose

Track findings from QA of the native A/B testing workflow. Findings remain open until the
corresponding fix has been implemented and verified. Rework will be completed one finding at a
time.

## Findings

### 1. Manage Experiments Link Opens Alternatives

- [ ] Fix and verify
- Status: Open

#### Observed Behavior

The **Manage Experiments** link incorrectly opens the Alternatives view.

#### Expected Behavior

The link opens the Experiments view for the current project.

### 2. Decision Point Selection Leaves Modal Backdrop Visible

- [ ] Fix and verify
- Status: Open

#### Observed Behavior

When an author selects a decision point to insert into a page, the selection modal is hidden but
the screen remains dark as though a modal is still displayed.

#### Expected Behavior

Selecting a decision point closes the modal and removes its backdrop so the authoring page is
fully interactive and displayed normally.

### 3. Authoring Preview Cannot Switch Decision Point Options

- [ ] Fix and verify
- Status: Open

#### Observed Behavior

Authoring Preview does not allow an author to preview the different options associated with a
decision point.

#### Expected Behavior

Authoring Preview provides a way to select and preview each option associated with a decision
point.

### 4. Completion Includes Hidden Decision Point Options

- [ ] Fix and verify
- Status: Open

#### Observed Behavior

Completion shows 50% when a decision point has two alternatives/options, even though only one is
displayed to the learner.

#### Expected Behavior

Completion percentage is calculated using only the alternatives/options displayed to the learner.
Hidden decision point options do not count toward the learner's completion denominator.

## Completion Checklist

- [ ] All four findings have an implemented fix.
- [ ] Each finding has regression coverage appropriate to the affected surface.
- [ ] Each finding has been manually verified in the QA workflow.
- [ ] The full A/B testing QA workflow has been rerun after all fixes are complete.
