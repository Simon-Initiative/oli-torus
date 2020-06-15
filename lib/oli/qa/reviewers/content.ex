defmodule Oli.Qa.Reviewers.Content do
  import Ecto.Query, warn: false
  import Oli.Qa.Utils
  alias Oli.Qa.{UriValidator}
  alias Oli.Authoring.Course
  alias Oli.Qa.{Warnings, Reviews}

  def review(project_slug) do
    {:ok, review} = Reviews.create_review(Course.get_project_by_slug(project_slug), "content")
    review
    |> broken_uris
    |> Reviews.mark_review_done

    project_slug
  end

  def broken_uris(review) do
    ["a", "img"]
    |> elements_of_type(review)
    |> UriValidator.invalid_uris
    |> Enum.each(&Warnings.create_warning(%{
      review_id: review.id,
      revision_id: &1.id,
      subtype: "broken #{&1.prettified_type}",
      content: &1.content
    }))

    review
  end
end
