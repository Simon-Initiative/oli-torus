# Attempt handling

When the underlying page or activity has a new revision available due to the
instructor applying a new course project publication, Torus handles existing page and
activity attempts in different ways depending on the attempt state.

## Ungraded Pages

Here is how updates to content are applied to attempts in ungraded pages:

- _Evaluated_ or _Submitted_: Evaluated and submitted attempts are affected in no way
  by new revision publication.
  These attempts always maintain a reference to the revision of the page or the activity
  that existed at the time of submission or evaluation. If a student "Resets" an evaluated attempt to
  create another attempt, this new attempt will always show the content of the most recentl
  published revision.
- _Active_: Active activity attempts are left as-is by the system until the time that the
  student accesses the page again. In this
  manner, a student that is in the middle of interacting with a page that contains
  activities will not have this content updated by new revision publication. It is only at the time that a student revisits a page that
  has an active attempt where
  Torus will detect that a new revision of the page or activity is available. There are
  two cases to consider here:

  1. The page itself has a new revision available. In this case, Torus simply creates a
     new page attempt record with all new activity attempt records for the student. The reasoning here
     is that since actual page content itself has changed the system should give all new activity
     attempts to allow the student to see these activities in the context of the latest page content.
  2. Only activity revisions have changed. In this case, a new activity attempt will be created
     for each of only the changed activities. No new page attempt is created.

- _Non existent_: For pages that a student has never visited, there is of course no attempt
  hierarchy present. At the time of first visit, the student will always encounter the latest published
  revision for the page and activities.

## Graded Pages

- _Evaluated_ or _Submitted_: Both evaluated and submitted attempts for graded pages are affected in no way by new revision publication.
  Similar to ungraded page attempts, these attempts always maintain a reference to the revision of the page or the activity that existed at the time of finalization.
- _Active_: Active activity attempts are left as-is by the system. In this
  manner, a student that is in the middle of interacting with a graded page will not have the content
  that they see updated by new revision publication. Even if the student leaves the page, and then
  returns, they will continue to see their attempt that is pinned to the original content. After the student
  submits the entire assessment for evaluation, subsequent attempts will show the newly published content.
- _Non existent_: For graded pages that a student has never visited, there is of course no attempt
  hierarchy present. At the time of first visit, the student will always encounter the latest published
  revision for the page and activities.
