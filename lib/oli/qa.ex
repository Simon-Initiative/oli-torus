defmodule Oli.Qa do
  @moduledoc """
  Qa uses two tables:
    1) Reviews
    2) Warnings

  The reviews table links a project to a high-level review "type," for example accessibility, content, or pedagogy.
  Reviews are marked completed when all of the warnings for that type are finished processing and created.
  Reviews are used in the UI to keep track of the progress of course reviews: some reviews may take longer to
  run than others, for example if they are resolving remote URLs or doing complex parsing logic across many resources.

  The warnings table links a review to specific action item a author can take to improve their project.
  Each warning has a subtype which indicates what explanation and action item should be shown to the author.
  Warnings are directly shown in the UI as a list of dismissable action items.

  For example, the structure looks something like this:
    Project ->
      Many reviews of type "accessibility," "pedagogy," etc.
      A review may be completed or still processing
      Review ->
        Many warnings of subtype "broken link," "no attached objectives," etc.
        A warning usually has some content that contains the issue (like the json for the broken link).
        It also maps to a description and an action item in the `ProjectView`.
  """

  alias Oli.Authoring.Course
  alias Oli.Qa.{Reviews}
  alias Oli.Qa.Reviewers.{Accessibility, Content, Pedagogy}

  def review_project(project_slug) do
    Reviews.delete_reviews(Course.get_project_by_slug(project_slug).id)

    # Each review must create a row in the review table for the review type
    # When the review is completed (all warnings finished processing), it must be marked as done.
    project_slug
    |> Accessibility.review()
    |> Content.review()
    |> Pedagogy.review()
  end
end
