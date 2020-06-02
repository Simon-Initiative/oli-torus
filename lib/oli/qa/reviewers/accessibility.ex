defmodule Oli.Qa.Reviewers.Accessibility do
  import Ecto.Query, warn: false
  import Oli.Qa.Utils
  alias Oli.Authoring.Course
  alias Oli.Qa.{Warnings, Reviews}

  def review(project_slug) do
    {:ok, review} = Reviews.create_review(Course.get_project_by_slug(project_slug), "accessibility")

    review
    |> missing_alt_text
    |> nondescriptive_link_text
    |> Reviews.mark_review_done

    project_slug
  end

  def missing_alt_text(review) do
    [ "img", "youtube" ]
    |> elements_of_type(review)
    |> Enum.filter(&no_alt_text?/1)
    |> Enum.each(&Warnings.create_warning(%{
      review_id: review.id,
      revision_id: &1.id,
      subtype: "missing alt text",
      content: &1.content
    }))

    review
  end

  defp no_alt_text?(%{ content: content } = _element) do
    !Map.has_key?(content, "alt")
  end

  defp nondescriptive_link_text(review) do
    ["a"]
    |> elements_of_type(review)
    |> Enum.filter(&nondescriptive?/1)
    |> Enum.each(&Warnings.create_warning(%{
      review_id: review.id,
      revision_id: &1.id,
      subtype: "nondescriptive link text",
      content: &1.content
    }))

    review
  end

  defp nondescriptive?(_element) do
    # match with ["link", "click", "click here", "more", empty, single word, only images, etc]
    # Write a recursive descent text parser
    false
  end
end
