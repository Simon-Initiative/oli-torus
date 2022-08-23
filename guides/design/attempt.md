# Attempt design

Torus _attempts_ track student interaction and results for pages, activities and parts of activities.

## Attempt Hierarchy

Torus models attempts in a hierarchy that mirrors the hierarchical
structure of course content. So for every
page that a student visits in Torus a _page attempt_ record is created.
For every activity that exists on a visited page, an _activity
attempt_ record is created (which points back to the parent page attempt
record). Finally, for every part that an activity defines, a _part attempt_
record is created.

The entire attempt hierarchy is rooted in a _resource access_ record
that tracks, amongst other things, the rolled up student result (aka grade)
across all attempts.

## Attempt History

The Torus attempt hierarchy supports preservation of
historical attempts. Consider an example where a student takes a graded
assessment (i.e. a page) that contains two activities (each with one part) twice. The full
attempt hierarchy, with history, would look like the following:

```
Resource Access
--Page Attempt 1
----Activity A, Attempt 1
------Part 1, Attempt 1
----Activity B, Attempt 1
------Part 1, Attempt 1
--Page Attempt 2
----Activity A, Attempt 1
------Part 1, Attempt 1
----Activity B, Attempt 1
------Part 1, Attempt 1
```

As another example, consider an ungraded page that contains one activity
that a student attempts several times:

```
Resource Access
--Page Attempt 1
----Activity A, Attempt 1
------Part 1, Attempt 1
----Activity A, Attempt 2
------Part 1, Attempt 1
----Activity A, Attempt 3
------Part 1, Attempt 1
----Activity A, Attempt 4
------Part 1, Attempt 1
```

## Attempt States

Attempts can exist in multiple states. These states are:

- **Non-existent**: The student has yet to access the page, thus no attempt exists.
- **Active**: A student attempt is "active" when they are currently interacting
  with this page or activity therefore the attempt is "active".
- **Submitted**: The student submitted a response for an activity that requires manual
  instructor scoring, thus the attempt enters a "submitted" state. The attempt is now
  read-only for the student.
- **Evaluated**: The student response has been evaluated (whether automatically or manually) and a score has been recorded into the attempt record. The attempt is now read-only for both the instructor and student.
