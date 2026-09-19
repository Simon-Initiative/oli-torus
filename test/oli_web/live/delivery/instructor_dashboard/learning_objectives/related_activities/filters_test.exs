defmodule OliWeb.Delivery.InstructorDashboard.LearningObjectives.RelatedActivities.FiltersTest do
  use ExUnit.Case, async: true

  alias OliWeb.Delivery.InstructorDashboard.LearningObjectives.RelatedActivities.Filters

  defp row(attrs) do
    Map.merge(
      %{title: "Untitled", question_stem: "", total_attempts: 0, avg_score: 0.0},
      Map.new(attrs)
    )
  end

  defp params(overrides \\ %{}) do
    Map.merge(
      %{
        offset: 0,
        limit: 20,
        sort_by: :title,
        sort_order: :asc,
        text_search: nil,
        selected_attempts_ids: "[]",
        avg_score_selector: nil,
        avg_score_percentage: nil
      },
      overrides
    )
  end

  describe "decode_params/1" do
    test "maps the legacy column names onto the ones the rows carry" do
      assert Filters.decode_params(%{"sort_by" => "question_stem"}).sort_by == :title
      assert Filters.decode_params(%{"sort_by" => "attempts"}).sort_by == :total_attempts
      assert Filters.decode_params(%{"sort_by" => "percent_correct"}).sort_by == :avg_score
    end

    test "falls back to the defaults when values are missing or unusable" do
      decoded = Filters.decode_params(%{"limit" => "not a number"})

      assert decoded.limit == Filters.default_params().limit
      assert decoded.sort_order == Filters.default_params().sort_order
      assert decoded.sort_by == :title
      assert decoded.offset == 0
    end

    test "rejects a known atom that is not in the allow list" do
      assert Filters.decode_params(%{"sort_order" => "title"}).sort_order == :asc
    end
  end

  describe "apply/2" do
    test "searches the stem and the title, ignoring case" do
      rows = [
        row(title: "Alpha", question_stem: "What is entropy?"),
        row(title: "Beta", question_stem: "Define a mole")
      ]

      {count, [found]} = Filters.apply(rows, params(%{text_search: "ENTROPY"}))

      assert count == 1
      assert found.title == "Alpha"

      {_, [by_title]} = Filters.apply(rows, params(%{text_search: "beta"}))

      assert by_title.title == "Beta"
    end

    test "the attempts filter keeps zero-attempt rows under 'less than five'" do
      rows = [
        row(title: "None", total_attempts: 0),
        row(title: "Few", total_attempts: 3),
        row(title: "Many", total_attempts: 9)
      ]

      {_, kept} = Filters.apply(rows, params(%{selected_attempts_ids: "[2]"}))

      assert Enum.map(kept, & &1.title) == ["Few", "None"] |> Enum.sort()
      refute "Many" in Enum.map(kept, & &1.title)
    end

    test "the score filter compares whole percentages" do
      rows = [
        row(title: "Low", avg_score: 0.25),
        row(title: "High", avg_score: 0.80)
      ]

      {_, [low]} =
        Filters.apply(
          rows,
          params(%{avg_score_selector: :is_less_than_or_equal, avg_score_percentage: 50})
        )

      assert low.title == "Low"

      {_, [high]} =
        Filters.apply(
          rows,
          params(%{avg_score_selector: :is_greather_than_or_equal, avg_score_percentage: 50})
        )

      assert high.title == "High"
    end

    test "sorts by the requested column and direction" do
      rows = [
        row(title: "b", total_attempts: 1, avg_score: 0.9),
        row(title: "A", total_attempts: 7, avg_score: 0.1)
      ]

      {_, by_title} = Filters.apply(rows, params(%{sort_by: :title, sort_order: :asc}))
      assert Enum.map(by_title, & &1.title) == ["A", "b"]

      {_, by_attempts} =
        Filters.apply(rows, params(%{sort_by: :total_attempts, sort_order: :desc}))

      assert Enum.map(by_attempts, & &1.total_attempts) == [7, 1]

      {_, by_score} = Filters.apply(rows, params(%{sort_by: :avg_score, sort_order: :asc}))
      assert Enum.map(by_score, & &1.avg_score) == [0.1, 0.9]
    end

    test "reports the total before pagination, not the page size" do
      rows = Enum.map(1..7, &row(title: "Row #{&1}", total_attempts: &1))

      {count, page} = Filters.apply(rows, params(%{offset: 2, limit: 3}))

      assert count == 7
      assert length(page) == 3
      assert Enum.map(page, & &1.total_attempts) == [3, 4, 5]
    end
  end

  describe "update_params/2" do
    test "toggles the direction when the same column is selected again" do
      current = %{sort_by: :title, sort_order: :asc}

      assert Filters.update_params(current, %{sort_by: :title}).sort_order == :desc

      assert Filters.update_params(%{current | sort_order: :desc}, %{sort_by: :title}).sort_order ==
               :asc
    end

    test "keeps the direction when a different column is selected" do
      updated =
        Filters.update_params(%{sort_by: :title, sort_order: :desc}, %{sort_by: :avg_score})

      assert updated.sort_by == :avg_score
      assert updated.sort_order == :desc
    end
  end

  describe "back_url_params/1" do
    test "decodes an encoded map and shrugs off anything else" do
      encoded = %{"back_params" => URI.encode(Jason.encode!(%{"tab" => "objectives"}))}

      assert Filters.back_url_params(encoded) == %{"tab" => "objectives"}

      assert Filters.back_url_params(%{"back_params" => %{"already" => "a map"}}) == %{
               "already" => "a map"
             }

      assert Filters.back_url_params(%{"back_params" => "not json at all"}) == %{}
      assert Filters.back_url_params(%{"back_params" => Jason.encode!([1, 2])}) == %{}
      assert Filters.back_url_params(%{}) == %{}
    end

    test "a list-shaped parameter falls back instead of crashing" do
      # `?back_params[]=%7B%7D` reaches the LiveView as a list, which `URI.decode/1` cannot take.
      assert Filters.back_url_params(%{"back_params" => ["{}"]}) == %{}
      assert Filters.back_url_params(%{"back_params" => 42}) == %{}
    end
  end
end
