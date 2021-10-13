defmodule Oli.Qa.Reviewers.Pedagogy do
  import Ecto.Query, warn: false

  require Logger

  alias Oli.Publishing
  alias Oli.Authoring.Course
  alias Oli.Resources
  alias Oli.Qa.{Warnings, Reviews}

  def review(project_slug) do
    # helpers
    pages = Publishing.get_unpublished_revisions_by_type(project_slug, "page")
    activities = Publishing.get_unpublished_revisions_by_type(project_slug, "activity")

    # logic
    case Reviews.create_review(Course.get_project_by_slug(project_slug), "pedagogy") do
      {:ok, review} ->
        review
        |> no_attached_objectives(activities)
        |> no_attached_activities(pages)
        |> Reviews.mark_review_done()

      {:error, e} ->
        Logger.error("failed to create review: #{inspect(e)}")
    end

    project_slug
  end

  def no_attached_objectives(review, revisions) do
    revisions
    |> Enum.filter(fn r ->
      Map.values(r.objectives) |> List.flatten() == []
    end)
    |> Enum.each(
      &Warnings.create_warning(%{
        review_id: review.id,
        revision_id: &1.id,
        subtype: "no attached objectives"
      })
    )

    review
  end

  def no_attached_activities(review, pages) do
    pages
    |> Enum.filter(&no_attached_activities?/1)
    |> Enum.each(
      &Warnings.create_warning(%{
        review_id: review.id,
        revision_id: &1.id,
        subtype: "no attached activities"
      })
    )

    review
  end

  defp no_attached_activities?(page) do
    page
    |> Resources.activity_references()
    |> Enum.empty?()
  end
end
