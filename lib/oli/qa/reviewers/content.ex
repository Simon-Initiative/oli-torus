defmodule Oli.Qa.Reviewers.Content do
  import Ecto.Query, warn: false
  import Oli.Qa.Utils
  alias Oli.Qa.{UriValidator}
  alias Oli.Authoring.Course
  alias Oli.Publishing
  alias Oli.Qa.Reviewers.Content.SelectionWorker
  alias Oli.Qa.{Warnings, Reviews}

  def review(project_slug) do
    {:ok, review} = Reviews.create_review(Course.get_project_by_slug(project_slug), "content")

    review
    |> broken_uris(project_slug)
    |> unfulfilled_selections(project_slug)
    |> Reviews.mark_review_done()

    project_slug
  end

  def broken_uris(review, project_slug) do
    ["a", "img"]
    |> elements_of_type(review)
    |> UriValidator.invalid_uris(project_slug)
    |> Enum.each(
      &Warnings.create_warning(%{
        review_id: review.id,
        revision_id: &1.id,
        subtype: "broken #{&1.prettified_type}",
        content: &1.content
      })
    )

    review
  end

  def unfulfilled_selections(review, project_slug) do
    project = Course.get_project_by_slug(project_slug)
    publication_id = Publishing.get_unpublished_publication_id!(project.id)

    ["selection"]
    |> elements_of_type(review)
    |> Enum.each(fn %{content: selection, id: id} ->
      %{
        review_id: review.id,
        publication_id: publication_id,
        project_slug: project_slug,
        selection: selection,
        revision_id: id
      }
      |> SelectionWorker.new()
      |> Oban.insert()
    end)

    review
  end
end
