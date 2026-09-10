# Manual QA — MER-5871: Suppressed Unit Numbering Consistency

## Goal

Confirm that when a section hides a top-level unit from numbering
(`unnumbered_unit_ids`), **every** course view shows the same numbering as
Learn — the suppressed unit has no number prefix, units before it keep
their number unchanged, and units after it are renumbered down to close the
gap. Also confirm that sections with **no** suppression configured look
exactly as they did before this fix (regression check).

You will create two courses and walk through the same list of views in both:

- **Course A** — the **middle** top-level unit is excluded from numbering.
  Suppressing a middle unit (not the first) is the strongest test: it
  proves units *before* it are untouched, the suppressed one disappears,
  and only units *after* it shift down.
- **Course B** — control course, nothing excluded.

### Prerequisites

- An account with **Admin** access. Creating the project and the Product/
  Template itself may work with a lower author role, but creating the
  course *section* specifically requires the Admin Panel (account menu →
  "Admin Panel" → Browse all Course Sections → New Section), which is
  gated to actual Admins in the code (`Accounts.is_admin?/1`).
- Two separate logins to test with: one **Instructor** account (yours) and
  one **Student** account (a second test user you enroll). You'll be
  switching between the two throughout Part 1/2, so it's easiest to keep
  them in **two separate browser sessions at once** — e.g. your normal
  browser window logged in as Instructor, and a second incognito/private
  window (or a different browser) logged in as the Student. That way you
  don't have to log out/in every time a step alternates roles, and you can
  keep both windows side by side to compare.
- Alternative to a second Student login: Instructor Dashboard → **Manage**
  has a **"Preview Course as Student"** link (opens Learn in a new tab, in
  preview mode). That's enough for 1.1 (Learn) but **not** for 1.3, 1.7, or
  1.9, which need a real enrolled student with real submitted/visited work
  — for those you do need the second account.

---

## Setup

### Course A — with a suppressed middle unit

1. As an Admin/Content Developer, create a new project with **3 top-level
   units**, each with **2 modules**, each module with **2 pages** of mixed
   types (details below). Use titles that don't look like a numbered label
   ("Unit 1", etc.), so a bug is obvious instead of blending in:

   - **Unit 1 — "Foundations"** (stays numbered, unchanged)
     - Module: "Getting Started"
       - Page: "Intro Reading" — plain, ungraded
       - Page: "Foundations Quiz" — **graded**
     - Module: "Setup Basics"
       - Page: "Setup Practice" — ungraded (**practice**)
       - Page: "Foundations Survey" — ungraded (**practice**), **with a
         survey content block** added in the page editor
   - **Unit 2 — "Data Analysis"** (this is the one you'll suppress)
     - Module: "Working with Data"
       - Page: "Analysis Basics" — plain, ungraded
       - Page: "Data Analysis Quiz" — **graded**
     - Module: "Visualization Techniques"
       - Page: "Chart Practice" — ungraded (**practice**)
       - Page: "Data Analysis Survey" — ungraded (**practice**), **with a
         survey content block**
   - **Unit 3 — "Statistics"** (stays numbered, will renumber down to "Unit 2")
     - Module: "Probability Intro"
       - Page: "Probability Reading" — plain, ungraded
       - Page: "Probability Exam" — **graded**
     - Module: "Distributions"
       - Page: "Distribution Practice" — ungraded (**practice**)
       - Page: "Statistics Survey" — ungraded (**practice**), **with a
         survey content block**

   Note on "survey": it's **not** a third page type alongside
   graded/practice. `graded` is a strict yes/no on the page itself (drives
   whether a page is a "scored" or "practice" page); "survey" is an
   unrelated, orthogonal thing — the Instructor Dashboard's survey list is
   just any page whose **content model contains a survey-type block**,
   regardless of whether that page is graded or not
   (`DeliveryResolver.pages_with_surveys/1`). So each "Survey" page above
   is simply a practice page that also has a survey block added in
   Authoring's page editor — it will show up in **both** the practice
   pages list and the surveys list.

   When creating each page in Authoring, set its type in the page's
   settings panel (exact labels may vary slightly by version — confirm
   against the live UI):
   - **Graded**: enable "Graded Assessment" / scoring in the page's
     Settings. Leave it off for every other page (that's what makes it a
     "practice" page).
   - **Survey block**: for the 3 "Survey" pages, add a Survey question/
     block to the page's content in the page editor — this is what makes
     it show up in the surveys list, not a Settings toggle.

   This mix matters: Assessment Settings and Student Exceptions only show
   **graded** pages, and the Instructor Dashboard pages list splits pages
   into separate **scored / practice / survey** lists — with only plain
   pages you'd see empty lists in several views below.

2. Publish the project.
3. **Important**: the "exclude the following units" control only exists on
   a course **Product** (called a "Template" in the UI) — a directly-created
   course section's own Settings page only has the plain on/off "Display
   curriculum item numbers" toggle, with no per-unit exclusion list. So to
   configure suppression at all, you need to go through a Product first:
   1. From your project's own Authoring page, open the left sidebar's
      **Publish** icon (a dropdown) → **Templates**. This lands on that
      project's own product list (a different page than the global
      "Browse all Templates" admin list — this one always has a "New
      Template" button, the global one doesn't).
   2. Click **"New Template"**, give it a title in the modal that appears.
      This creates the product and takes you straight to its **Details**
      page.
   3. Under **Presentation**, check **"Display curriculum item numbers"**
      (the exclusion list is disabled/greyed out until this is checked).
   4. In **"Exclude the following units"**, open the multi-select and
      check **"Data Analysis"** (the middle unit). This saves
      automatically on change — no separate Save button.
4. Create the actual course section **from that Product**, not directly
   from the publication: click your account avatar (top right) →
   **"Admin Panel"** → under **Content Management**, **"Browse all Course
   Sections"** → **"New Section"** button. This opens a wizard: **"Select
   source"** (pick the Product/Template you just configured, not the raw
   project) → **"Name your course"** → course details to finish. The new
   section inherits the product's numbering settings (including the
   exclusion) at creation time — this only works if you selected the
   Product as the source, not the plain project/publication. Creating the
   section redirects you straight to that section's **Manage** page — this
   is your anchor point for everything in Part 1 below. Every "Instructor
   Dashboard" reference from here on means this section's own pages, using
   the persistent top nav bar (**Overview** / **Insights** / **Manage** /
   Discussion Activity) to move between them.
5. Enroll yourself as Instructor, and create/enroll a second test user as
   Student.
   - Note: there is currently no UI to change `unnumbered_unit_ids` on the
     course section itself after it's created — only on the source Product,
     before creating the section. If you need to change which unit is
     excluded later, edit the Product and create a new section from it (or
     ask an engineer to update it directly via `iex`).
6. From this point on, the expected numbering everywhere is:
   - **"Foundations" = Unit 1** (unchanged — it comes before the suppressed
     unit).
   - **"Data Analysis" = no number at all** (suppressed).
   - **"Statistics" = Unit 2** (renumbered down from "Unit 3", since
     "Data Analysis" no longer consumes a numbering slot).
   - Modules are numbered **globally across the whole course**, not reset
     per unit. So: "Getting Started" = Module 1, "Setup Basics" = Module 2
     (both unchanged, before the suppressed unit); "Working with Data" and
     "Visualization Techniques" have no number (inside the suppressed
     unit); "Probability Intro" = Module 3 and "Distributions" = Module 4
     (shifted down from 5 and 6, skipping the 2 module slots the suppressed
     unit no longer consumes).
7. Log in as the Student and complete/submit **"Foundations Quiz"** (in
   the unaffected Unit 1) and **"Probability Exam"** (in the renumbered
   Unit 2). This gives Student Insights and Student Progress real,
   non-empty data to check in both an unchanged and a renumbered unit.

### Course B — control (nothing suppressed)

1. Repeat step 1 above (same project, or a new one with the same
   structure).
2. Publish it, then create a section the same way as Course A's step 4
   (Admin Panel → Browse all Course Sections → New Section), but at the
   "Select source" step pick the **project** directly, not a Product — no
   Product/Template detour needed here, since nothing needs to be
   excluded. This must look exactly as it did before this fix in every
   view below — "Foundations" = Unit 1, "Data Analysis" = Unit 2,
   "Statistics" = Unit 3, modules 1 through 6 in original document order.
3. Enroll yourself as Instructor and a second test user as Student.
4. Same as Course A's step 7 above: have the student complete one graded
   page in Unit 1 and one in Unit 3, so Course B has comparable data to
   Course A.

---

## Part 1 — Course A (with a suppressed middle unit)

### 1.1 — Learn (student view)

- **View**: Learn, the course landing page for a student.
- **How to get there**: Log in as the student and open the section (lands
  on Learn), or as the instructor: **Manage** → **"Preview Course as
  Student"**.
- **What to do**: Look at the top-level unit list.
- **What to check**:
  - "Foundations" appears as **"Unit 1: Foundations"** — unchanged.
  - "Data Analysis" appears with **no** number at all — just "Data
    Analysis".
  - "Statistics" appears as **"Unit 2: Statistics"** — renumbered down
    from 3.
  - This view already worked correctly before this fix — use it as the
    reference "ground truth" for every other view below.

### 1.2 — Scheduling and Assessment Settings (Schedule / Assessment Settings / Student Exceptions tabs)

Reached via **one single Manage link** — Instructor Dashboard → **Manage**
→ **"Scheduling and Assessment Settings"** — which lands on a page with 4
tabs: **Schedule**, **Assessment Settings**, **Student Exceptions**, and
**Advanced Gating** (not relevant here). Check the first three.

- **Schedule tab**: look at the unit/module labels on the schedule items,
  and in the side panel/slideout when clicking a scheduled item.
  - **What to check**:
    - Items under "Foundations" still show "Unit 1".
    - Items under "Data Analysis" show with no unit number (not a literal
      blank/"null" number).
    - Items under "Statistics" show "Unit 2", not "Unit 3".
- **Assessment Settings tab**: open the "apply to all assessments"
  bulk-apply `<select>` dropdown (used to bulk-set exceptions across
  assessments).
  - **Note on the label shown**: this dropdown labels a page with its
    **most specific parent container**, not necessarily the top-level
    unit. All three graded pages here sit inside a module (not directly
    inside a unit), so you'll see the **module** number, not the unit
    number — that's correct, not a bug.
  - **What to check**:
    - "Foundations Quiz" (in module "Getting Started", unaffected by
      suppression) is grouped under **"Module 1: Foundations Quiz"**.
    - "Data Analysis Quiz" (in module "Working with Data", itself inside
      the suppressed unit) shows as plain **"Data Analysis Quiz"** — no
      module/unit prefix at all, since its whole parent chain up to the
      suppressed unit is dropped.
    - "Probability Exam" (in module "Probability Intro") is grouped under
      **"Module 3: Probability Exam"** — renumbered down from "Module 5"
      (skipping the 2 module slots the suppressed unit's modules no
      longer consume). Never "Module 5".
- **Student Exceptions tab**: open the assessment selector dropdown.
  - **What to check**: Same labels as the Assessment Settings tab above,
    for all three graded pages. This is the exact bug originally reported
    in the ticket: before this fix, a page whose module comes after a
    suppressed unit showed its old (un-shifted) module number here while
    Learn already showed the shifted one.

*(Grade Sync / "Manage LMS Gradebook" is intentionally not part of this
walkthrough — it only appears for LTI/LMS-connected sections, not Open &
Free ones like Course A/B, and it's already covered by an automated test,
`test/oli_web/live/grades_live_test.exs`.)*

### 1.3 — Content tab (Order column, navigator, and per-container Student Insights)

Instructor Dashboard → **Insights** → **Content** — check it at three
points as you drill in, not three separate tabs:

- **Top-level view (nothing selected yet)**: look at the **"Order"**
  column for every unit/module row, with the **units** filter selected
  first (so the 3 units are the only rows).
  - **What to check (values)**:
    - "Foundations" and its 2 modules show order values consistent with
      Unit 1 / Modules 1–2.
    - "Data Analysis" and its 2 modules show **no** order value (blank,
      not "0" or garbage).
    - "Statistics" and its 2 modules show order values consistent with
      Unit 2 / Modules 3–4 (not 3 / 5–6).
  - **What to check (row order — click the "Order" column header to
    sort)**:
    - **Ascending** (default): rows appear in document order — Foundations,
      Data Analysis, Statistics. "Data Analysis" sits **between** the
      other two, not at the bottom of the table.
    - **Descending** (click "Order" again to flip): rows appear as the
      exact mirror — Statistics, Data Analysis, Foundations. "Data
      Analysis" must **still** sit in the middle, not jump to the *top*
      of the table. (This was the clearest version of the bug this
      section covers: a blank/unnumbered row sorting first when sorting
      "highest to lowest" makes no sense under any reading of "Order".)
- **The unit/module selector dropdown at the top of the same page** (used
  to jump to a specific unit/module): click the current unit/module name to
  open the searchable dropdown, and scan every entry, in order.
  - **What to check (labels)**:
    - "Unit 1: Foundations" and its modules read "Module 1: Getting
      Started", "Module 2: Setup Basics".
    - "Data Analysis" and its modules appear with plain titles only, no
      "Unit :" / "Module :" / "nil" prefix anywhere.
    - "Unit 2: Statistics" and its modules read "Module 3: Probability
      Intro", "Module 4: Distributions".
  - **What to check (item order)**: the dropdown list, top to bottom,
    must read exactly: Foundations, Getting Started, Setup Basics, Data
    Analysis, Working with Data, Visualization Techniques, Statistics,
    Probability Intro, Distributions. In particular, "Visualization
    Techniques" (Data Analysis's second module) must appear **before**
    "Statistics", not after it — it belongs to the suppressed unit's own
    subtree, not to whatever comes next in the course.
- **After selecting a unit from that dropdown** (this lands you on a
  per-container detail view, heading + a per-student data table): select
  each of the three units in turn.
  - **What to check**:
    - Selecting "Foundations" shows heading **"Unit 1: Foundations Student
      Insights"**.
    - Selecting "Data Analysis" shows heading plain **"Data Analysis
      Student Insights"** — no "Unit :" or "Unit nil:" text anywhere.
    - Selecting "Statistics" shows heading **"Unit 2: Statistics Student
      Insights"**.
    - The test student's row shows real progress/score data for
      "Foundations Quiz" (inside Unit 1) and for "Probability Exam"
      (inside the renumbered Unit 2).

### 1.4 — Instructor Dashboard → Learning Objectives tab, container navigator

- **View**: Learning Objectives (Insights).
- **How to get there**: Instructor Dashboard → **Insights** → **Learning
  Objectives**.
- **What to do**: Click the current unit/module name to open the same
  style of container navigator dropdown as 1.3.
- **What to check**: Same as 1.3's dropdown check (both labels and item
  order), for every unit/module.

### 1.5 — Instructor Dashboard → Dashboard tab

- **View**: Dashboard (Insights) — also referred to as the "Intelligent
  Dashboard" internally; the visible tab label is just **"Dashboard"**. May
  require a feature flag to be visible — skip if not present for this
  section.
- **How to get there**: Instructor Dashboard → **Insights** →
  **Dashboard**.
- **What to do**: Click the current scope name at the top (defaults to
  "Entire Course") to open the same style of searchable dropdown as
  1.3/1.4.
- **What to check (labels)**: Same numbering pattern as 1.3's dropdown
  check, for all three units.
- **What to check (item order)**: same expected order as 1.3's dropdown —
  Foundations, its 2 modules, Data Analysis, its 2 modules, Statistics, its
  2 modules. This dropdown groups by unit differently internally (it
  builds a tree and flattens it, rather than one flat query), so it's
  worth checking independently of 1.3/1.4 rather than assuming "it uses
  the same code": "Data Analysis" and its 2 modules must **not** be pushed
  to the very end of the list, after "Distributions" — if you see the
  suppressed unit's whole subtree bunched up at the bottom, that's the
  bug.

### 1.6 — Instructor Dashboard → Scored/Practice/Surveys tabs + CSV export

These are three separate tabs under Insights (not part of the "Content" tab
from 1.3) — **Scored Pages**, **Practice Pages**, and **Surveys**, each a
flat list of pages of that type with a container-label column. Check all
three.

- **View**: Scored Pages / Practice Pages / Surveys.
- **How to get there**: Instructor Dashboard → **Insights** → **Scored
  Pages** (then separately **Practice Pages**, then **Surveys** — three
  distinct tabs in the Insights sub-nav).
- **What to do**: On **Scored Pages**, check the container-label column for
  "Foundations Quiz", "Data Analysis Quiz", "Probability Exam", then click
  the **"Download CSV"** button on that tab. Repeat on **Practice Pages**
  for "Setup Practice", "Chart Practice", "Distribution Practice" (this
  tab also has its own "Download CSV" button). Repeat on **Surveys** for
  "Foundations Survey", "Data Analysis Survey", "Statistics Survey" (no
  download button here —
  CSV export only exists for Scored and Practice).
- **Note on the label shown**: like 1.2's Assessment Settings tab, this
  "container" column shows the page's **immediate parent module's own
  label** ("Module N: <module title>") — not the top-level unit. When that
  module itself sits inside the suppressed unit, it falls back to the
  **bare module title**, no "Module N:" prefix (and, unlike Assessment
  Settings, it does **not** disappear entirely — you still see the module
  name, just unnumbered).
- **What to check** (same pattern on all three tabs — Scored, Practice,
  Surveys):
  - "Foundations Quiz" / "Setup Practice" / "Foundations Survey" show
    **"Module 1: Getting Started"** / **"Module 2: Setup Basics"**
    respectively (both modules are in the unaffected Unit 1).
  - "Data Analysis Quiz" / "Chart Practice" / "Data Analysis Survey" show
    the bare module title — **"Working with Data"** / **"Visualization
    Techniques"** — no "Module N:" prefix, since those modules are inside
    the suppressed unit.
  - "Probability Exam" / "Distribution Practice" / "Statistics Survey"
    show **"Module 3: Probability Intro"** / **"Module 4: Distributions"**
    — renumbered down from 5/6, never showing the old numbers.
  - In the exported CSVs (Scored and Practice): same labels — no title
    contains "Module 5", "Module 6", or a literal "null".

### 1.7 — Student Progress breadcrumbs

- **View**: the test student's own **Progress** tab — a table of every
  page in the course, with columns # / Resource Title / Type / Score /
  # Attempts / # Accesses / First Visited / Last Visited. The "Resource
  Title" column shows a small breadcrumb line **above** each page's title
  link — that breadcrumb is what this step checks.
- **How to get there**: get into the test student's own Student Dashboard
  (same place as 1.9 — e.g. from the "Students" list under Overview, click
  the student's name) → **Progress** tab (a tab of its own, separate from
  Content/Learning Objectives/Assessment Scores).
- **What to do**: find the rows for "Foundations Quiz" and "Probability
  Exam" in the table and read the small breadcrumb line above each title.
- **What to check**:
  - The breadcrumb separator is **"/"**, not ">".
  - "Foundations Quiz"'s breadcrumb includes "Module 1" (its parent
    module, "Getting Started" — unaffected, before the suppressed unit).
  - "Probability Exam"'s breadcrumb includes "Module 3" (its parent
    module, "Probability Intro" — renumbered down from "Module 5") — not
    "Module 5".
  - Neither breadcrumb should ever show a literal "nil" segment.

### 1.8 — Instructor Dashboard → Overview → Course Content

**Correction**: an earlier version of this document pointed this step at a
"Student Dashboard → Course Content" tab. That surface (`CourseContentLive`)
turned out not to be reachable from any real navigation in the running
app — it's only ever mounted directly in its own test, never linked from
anywhere in the UI. The actual reachable surface backed by the same
`previous_next_index`/`Sections.build_hierarchy/1` mechanism (Phase 7's
fix) is on the **Instructor** Dashboard, under **Overview**.

- **View**: Course Content — a browsable outline/tree of the course
  (units → modules → pages), instructor-facing.
- **How to get there**: Instructor Dashboard → **Overview** → **Course
  Content**.
- **What to do**: Expand the tree and look at the unit/module labels.
- **What to check**:
  - Labels match Learn exactly: "Unit 1: Foundations", "Data Analysis"
    with no number, "Unit 2: Statistics".
  - This view is backed by a persisted cache (`previous_next_index`); if
    this section existed **before** this fix was deployed, its cache may
    need the one-time data migration to refresh. If numbers look stale
    here specifically, that's the signal to check whether the migration
    ran (see the phase 7 execution record) rather than a new bug.

### 1.9 — Student Dashboard → Learning Objectives (a *different* tab from 1.4)

This is easy to confuse with 1.4 ("Learning Objectives" on the Instructor
Dashboard) — they're two separate LiveViews with separate code, reached
from different places, even though they have the same tab name. This one
is the **Student Dashboard's own** Learning Objectives tab: an instructor
drills into one specific student's dashboard, which has its own set of
tabs (Content, Learning Objectives, Assessment Scores, Progress, Actions).

- **View**: Learning Objectives, inside a specific student's Student
  Dashboard.
- **How to get there**: click the test student's **name** anywhere it's a
  link (e.g. the "Students" list under Overview, or a student row in 1.3's
  Student Insights view) — this opens their Student Dashboard on its
  **Content** tab by default — then click over to the **Learning
  Objectives** tab.
- **What to do**: Click the current unit/module name to open the
  container navigator dropdown (same style component as 1.3/1.4/1.5).
- **What to check**: Same as 1.4 — both labels ("Unit 1: Foundations",
  bare "Data Analysis", "Unit 2: Statistics", etc.) and item order (Data
  Analysis's modules must stay between Foundations's and Statistics's).
  This surface had **no suppression handling of any kind** before this
  fix — a suppressed unit showed its raw, un-suppressed number here
  (e.g. literally "Unit 2: Data Analysis") instead of no number at all, so
  if you see any raw/un-suppressed numbers on this specific tab, check
  this one first — it's the newest and least-tested of all the surfaces
  in this document.

---

## Part 2 — Course B (control, nothing suppressed)

Same views as Part 1, same navigation paths. Since nothing is excluded from
numbering, every view below should look **exactly as it did before this
fix** — plain, sequential numbering (Unit 1/2/3, Module 1 through 6), no
gaps, nothing hidden, no view disagreeing with any other.

| # | View | Expected result |
|---|------|------------------|
| 2.1 | Learn | Foundations = Unit 1, Data Analysis = Unit 2, Statistics = Unit 3. Modules 1–6 in document order. |
| 2.2 | Scheduling and Assessment Settings — Schedule / Assessment Settings / Student Exceptions tabs | Schedule tab: same numbers as Learn. Assessment Settings & Student Exceptions tabs: module-level labels — "Module 1: Foundations Quiz", "Module 3: Data Analysis Quiz", "Module 5: Probability Exam". |
| 2.3 | Content tab — "Order" column (both sort directions), unit/module selector dropdown, per-container Student Insights | Order column and dropdown: "Unit 1: Foundations" ... "Unit 3: Statistics", modules 1–6, nothing blank, same order ascending and mirrored descending. Student Insights headings: "Unit N: <title> Student Insights"; both students' submissions show correctly. |
| 2.4 | Learning Objectives — container navigator | Same as 2.3's dropdown (labels + order). |
| 2.5 | Dashboard tab | Same as 2.3's dropdown (labels + order; skip if not enabled). |
| 2.6 | Scored/Practice/Surveys tabs + CSV export | Module-level labels 1–6 in document order (e.g. "Module 3: Working with Data", "Module 5: Probability Intro"), consistent on all 3 tabs and in the Scored/Practice CSVs. |
| 2.7 | Student Progress breadcrumbs | "Foundations Quiz" includes "Module 1", "Probability Exam" includes "Module 5" (not renumbered, nothing suppressed). |
| 2.8 | Instructor Dashboard — Overview → Course Content | Same numbers as Learn. |
| 2.9 | Student Dashboard — Learning Objectives (per-student) | Same as 2.4 (labels + order) — Unit 1/2/3, modules 1–6, nothing raw/un-suppressed. |

For each row: open the same view as the matching step in Part 1, and
confirm the numbering matches Learn with no unit missing a number and no
unit skipped. Any mismatch here would be a regression, since Course B has
no suppression configured at all.

---

## If something looks wrong

- A number showing as the literal text **"nil"** or **"null"** anywhere
  (e.g. "Unit nil: Data Analysis") is always a bug — file it against this
  PR, don't assume it's expected.
- A suppressed unit showing **any** number (even the wrong one) is a bug.
- A unit *before* the suppressed one changing its number is a bug (only
  units *after* the suppressed one should shift).
- Two views disagreeing on the number for the same non-suppressed unit is a
  bug.
- A suppressed unit (or its modules) appearing **out of its natural
  document position** — bunched at the top or bottom of a list/table
  instead of staying between its actual neighbors — is a bug, separate
  from the number itself being wrong. Check this specifically wherever a
  view lists multiple containers at once (1.3, 1.4, 1.5, 1.9): correct
  labels with wrong item order is still a bug.
- On the Content tab's "Order" column specifically (1.3), also check
  **descending** sort, not just the default ascending — a suppressed row
  jumping to the very top when sorting "highest to lowest" is a bug, even
  if the ascending view looks correct.
- If only the **Course Content** view (1.8) looks stale while everything
  else is correct, check the data migration first before treating it as a
  new bug — see `phase_7_execution_record.md`.
