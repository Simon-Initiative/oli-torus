# Overview

## Important concepts and terms

Torus operates broadly in two different modes:

- _Authoring_: Authoring mode is a set of features used by authors to create, update and publish the
  material within their course project.
- _Delivery_: Delivery mode is a set of features used by Instructors and Students during the
  delivery of course material to students in a course section.

The material with course projects is modeled as a collection of `Resources` of different
supported resource types. The following lists the various types of resources that exist:

- _Container_: A collection of pages or containers that can correspond to "Units" or "Modules" within a course.
- _Page_: A collection of content and activities that offer student instruction and assessment. Pages can be either "graded" or "practice".
- _Activity_: A scorable interaction used in both practice or assessment contexts.
- _Objective_: A learning objective that course content attempts to instruct and that activities offer
  practice and assessment on.
- _Tag_: A tag is a flexible mechanism that can power a variety of platform functionality such as
  activity bank selection.

Activities have several important concepts:

- _Activity type_: Torus supports a variety of different kinds of student interactive experiences
  such as multiple choice, ordering, and check all that apply.
- _Activity instance_: An activity instance is created when an author defines (aka "authors") a new
  activity of a supported activity type.
- _Activity reference_: Activity instances are not directly embedded into pages, rather a reference
  to an instance is stored within pages. This mechanism allows activity instances to be shared
  across pages.
- _Activity bank_: A collection of activity instances that can be randomly selected according to
  a defined set of criteria at delivery time. A page can contain _activity bank selections_ which
  allows the system to select and render different activities for each different student attempt.
- _Parts_: Activity instances have a collection of one or more _parts_. A part offers a mechanism
  to track student interaction and submission, and ultimately to store a system or instructor
  assign score. Some activity types have a fixed number of parts: for example a multiple choice activity
  has only one part which models which choice the student selected, their received score and any
  received feedback. Other activity types feature multiple parts, and in some cases the number of
  parts is dynamic and determined at the time that the author defines the activity instance. For
  example, an author can create a "Multi input" activity that features three "fill in the blank"
  text inputs in the middle of the question stem. This activity instance would have three parts, one
  for each of these inputs, and allows each of them to be scored individually.
- _Grading approach_: Each part within an activity instance can specify its required grading, or scoring, approach. The supported options are `automatic` and `manual`. Automatically scored
  parts require the definition of a collection of `responses` that specify the rules to use
  to allow the sytem to perform automatic scoring. Manually scored parts for activities ultimately
  require the instructor to review the submission for the part and to assign a score and provide
  feedback.
