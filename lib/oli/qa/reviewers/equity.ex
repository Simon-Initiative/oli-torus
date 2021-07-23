defmodule Oli.Qa.Reviewers.Equity do
  import Ecto.Query, warn: false
  import Oli.Qa.Utils
  alias Oli.Authoring.Course
  alias Oli.Qa.{Warnings, Reviews}

  @spec exclusive_phrases :: [{<<_::32, _::_*8>>, <<_::64, _::_*8>>}, ...]
  def exclusive_phrases() do
    [
      {"aging adult", "Consider rewording to avoid a potentially ageist phrasing"},
      {"elderly", "Consider rewording to avoid a potentially ageist phrasing"},
      {"poor people", "Consider using 'Economically disadvantaged'"},
      {"the homeless", "Consider using 'Economically disadvantaged'"},
      {"the less fortunate", "Consider using 'Economically disadvantaged'"},
      {"crippled", "Use neutral language when talking about a disability"},
      {"lame", "Use neutral language when talking about a disability"},
      {"handicapped", "Use neutral language when talking about a disability"},
      {"chairman", "Use gender neutral language"},
      {"mankind", "Use gender neutral language"},
      {"biological sex", "Use gender neutral language"},
      {"opposite sex", "Use gender neutral language"}
    ]
  end

  def review(project_slug) do
    {:ok, review} = Reviews.create_review(Course.get_project_by_slug(project_slug), "equity")

    review
    |> inclusive_language(project_slug)
    |> Reviews.mark_review_done()

    project_slug
  end

  def lang_check(elements, _) when is_list(elements) do
    {phrases, _} = Enum.unzip(exclusive_phrases())

    elements
    |> Enum.filter(fn e ->
      text(e.content) |> String.downcase() |> String.contains?(phrases)
    end)
  end

  def text(%{"type" => "p", "children" => children}) do
    Enum.reduce(children, "", fn c, s ->
      s <> text(c)
    end)
  end

  def text(%{"text" => text}) do
    text
  end

  def text(_) do
    " "
  end

  def inclusive_language(review, project_slug) do
    ["p"]
    |> elements_of_type(review)
    |> lang_check(project_slug)
    |> Enum.each(fn e ->
      {_, advice} =
        Enum.filter(
          exclusive_phrases(),
          fn {p, advice} -> String.contains?(text(e.content) |> String.downcase(), p) end
        )
        |> hd()

      Warnings.create_warning(%{
        review_id: review.id,
        revision_id: e.id,
        subtype: advice,
        content: e.content
      })
    end)

    review
  end
end
