defmodule OliWeb.Workspaces.CourseAuthor.StateLogicTest do
  use Oli.DataCase

  alias Oli.Qa.Reviewers.Pedagogy
  alias Oli.Qa.Reviewers.Content
  alias Oli.Publishing

  alias OliWeb.Common.SessionContext
  alias OliWeb.Workspaces.CourseAuthor.ReviewLive
  alias OliWeb.Workspaces.CourseAuthor.Qa.State

  def merge_changes(changes, state) do
    Map.merge(state, Enum.reduce(changes, %{}, fn {k, v}, m -> Map.put(m, k, v) end))
  end

  describe "qa live state" do
    setup do
      map =
        Seeder.base_project_with_resource2()
        |> Seeder.add_objective("I love writing objectives", :o1)
        |> Seeder.add_review("pedagogy", :review)
        |> Seeder.add_review("content", :content)

      map
      |> Seeder.add_page(%{objectives: %{"attached" => []}}, :page_no_objectives)
      |> Seeder.add_page(
        %{objectives: %{"attached" => [Map.get(map, :o1).resource.id]}},
        :page_has_objectives
      )
      |> Seeder.add_page(
        %{
          content: %{
            "model" => [
              %{
                "children" => [
                  %{
                    "children" => [
                      %{"text" => " "},
                      %{
                        "children" => [%{"text" => "link"}],
                        "href" => "gg",
                        "id" => "1914651063",
                        "target" => "self",
                        "type" => "a"
                      },
                      %{"text" => ""}
                    ],
                    "id" => "3636822762",
                    "type" => "p"
                  }
                ],
                "id" => "481882791",
                "purpose" => "None",
                "type" => "content"
              },
              %{
                "activity_id" => 10,
                "children" => [],
                "id" => "3781635590",
                "purpose" => "None",
                "type" => "activity-reference"
              }
            ]
          }
        },
        :page_has_activities
      )
      |> Seeder.add_activity(%{objectives: %{}}, :activity_no_objectives)
      |> Seeder.add_activity(%{objectives: %{}}, :activity_no_objectives)
      |> Seeder.add_activity(%{objectives: %{}}, :activity_no_objectives)
      |> Seeder.add_activity(
        %{objectives: %{"1" => [Map.get(map, :o1).resource.id]}},
        :activity_has_objectives
      )
      |> Map.put(
        :pages,
        Publishing.get_unpublished_revisions_by_type(Map.get(map, :project).slug, "page")
      )
      |> Map.put(
        :activities,
        Publishing.get_unpublished_revisions_by_type(Map.get(map, :project).slug, "activity")
      )
    end

    test "filtering", %{
      project: project,
      review: review,
      content: content,
      activities: activities,
      author: author
    } do
      Pedagogy.no_attached_objectives(review, activities)
      Content.broken_uris(content, project.slug)

      current_review = ReviewLive.read_current_review(project)
      context = SessionContext.init() |> Map.put(:author, author)

      state = State.initialize_state(context, project, current_review)

      # test filtering out of pedagogy, and ensure that a selected pedagogy item gets converted to the content warning
      first_pedagogy_warning =
        Enum.filter(state.warnings, fn w -> w.review.type == "pedagogy" end) |> hd

      first_content_warning =
        Enum.filter(state.warnings, fn w -> w.review.type == "content" end) |> hd

      state =
        State.selection_changed(state, Integer.to_string(first_pedagogy_warning.id))
        |> merge_changes(state)

      assert state.filters == MapSet.new(["pedagogy", "content", "equity", "accessibility"])
      assert length(state.filtered_warnings) == length(state.warnings)

      state =
        State.set_filters(state, State.toggle_filter(state, "pedagogy")) |> merge_changes(state)

      assert state.filters == MapSet.new(["content", "equity", "accessibility"])
      assert length(state.filtered_warnings) != length(state.warnings)
      assert state.selected == first_content_warning

      # turn off content filter, which should result then in zero warnings being displayed
      state =
        State.set_filters(state, State.toggle_filter(state, "content")) |> merge_changes(state)

      assert state.filters == MapSet.new(["accessibility", "equity"])
      assert length(state.filtered_warnings) == 0

      # bring back pedagody and select the first pedagogy, then bring back content,
      # ensuring that the selection of that pedagogy item remains
      state =
        State.set_filters(state, State.toggle_filter(state, "pedagogy")) |> merge_changes(state)

      assert state.filters == MapSet.new(["pedagogy", "accessibility", "equity"])

      state =
        State.selection_changed(state, Integer.to_string(first_pedagogy_warning.id))
        |> merge_changes(state)

      assert state.selected == first_pedagogy_warning

      state =
        State.set_filters(state, State.toggle_filter(state, "content")) |> merge_changes(state)

      assert state.filters == MapSet.new(["pedagogy", "content", "accessibility", "equity"])
      assert state.selected == first_pedagogy_warning
    end

    test "dismissal when the item is first selected", %{
      project: project,
      review: review,
      content: content,
      activities: activities,
      author: author
    } do
      Pedagogy.no_attached_objectives(review, activities)
      Content.broken_uris(content, project.slug)

      current_review = ReviewLive.read_current_review(project)
      context = SessionContext.init() |> Map.put(:author, author)

      state = State.initialize_state(context, project, current_review)

      # if we have the first one selected, it selects the second
      pedagogy_warnings = Enum.filter(state.warnings, fn w -> w.review.type == "pedagogy" end)
      first = Enum.at(pedagogy_warnings, 0)
      second = Enum.at(pedagogy_warnings, 1)
      state = State.selection_changed(state, Integer.to_string(first.id)) |> merge_changes(state)

      state = State.warning_dismissed(state, first.id) |> merge_changes(state)
      assert state.selected == second
    end

    test "dismissal when the item is last selected", %{
      project: project,
      review: review,
      content: content,
      activities: activities,
      author: author
    } do
      Pedagogy.no_attached_objectives(review, activities)
      Content.broken_uris(content, project.slug)

      current_review = ReviewLive.read_current_review(project)
      context = SessionContext.init() |> Map.put(:author, author)

      state = State.initialize_state(context, project, current_review)

      # if we have the last one selected, it selects the next to last
      pedagogy_warnings = Enum.filter(state.warnings, fn w -> w.review.type == "pedagogy" end)
      last = Enum.at(pedagogy_warnings, length(pedagogy_warnings) - 1)
      next_to_last = Enum.at(pedagogy_warnings, length(pedagogy_warnings) - 2)
      state = State.selection_changed(state, Integer.to_string(last.id)) |> merge_changes(state)

      state = State.warning_dismissed(state, last.id) |> merge_changes(state)
      assert state.selected == next_to_last
    end

    test "dismissal when the item is not first or last, but selected", %{
      project: project,
      review: review,
      content: content,
      activities: activities,
      author: author
    } do
      Pedagogy.no_attached_objectives(review, activities)
      Content.broken_uris(content, project.slug)

      current_review = ReviewLive.read_current_review(project)
      context = SessionContext.init() |> Map.put(:author, author)

      state = State.initialize_state(context, project, current_review)

      # if we have the second one selected, it selects the next (third)
      pedagogy_warnings = Enum.filter(state.warnings, fn w -> w.review.type == "pedagogy" end)
      third = Enum.at(pedagogy_warnings, 2)
      second = Enum.at(pedagogy_warnings, 1)
      state = State.selection_changed(state, Integer.to_string(second.id)) |> merge_changes(state)

      state = State.warning_dismissed(state, second.id) |> merge_changes(state)
      assert state.selected == third
    end

    test "dismissal when the dismissed is not selected", %{
      project: project,
      review: review,
      content: content,
      activities: activities,
      author: author
    } do
      Pedagogy.no_attached_objectives(review, activities)
      Content.broken_uris(content, project.slug)

      current_review = ReviewLive.read_current_review(project)
      context = SessionContext.init() |> Map.put(:author, author)

      state = State.initialize_state(context, project, current_review)

      # if we have the second one selected, it selects the next (third)
      pedagogy_warnings = Enum.filter(state.warnings, fn w -> w.review.type == "pedagogy" end)
      third = Enum.at(pedagogy_warnings, 2)
      second = Enum.at(pedagogy_warnings, 1)
      state = State.selection_changed(state, Integer.to_string(second.id)) |> merge_changes(state)

      state = State.warning_dismissed(state, third.id) |> merge_changes(state)
      assert state.selected == second
    end

    test "dismissing the last warning in a filtered state should not select a new warning for display",
         %{
           project: project,
           review: review,
           content: content,
           activities: activities,
           author: author
         } do
      Pedagogy.no_attached_objectives(review, activities)
      Content.broken_uris(content, project.slug)

      current_review = ReviewLive.read_current_review(project)
      context = SessionContext.init() |> Map.put(:author, author)

      state = State.initialize_state(context, project, current_review)

      state =
        State.set_filters(state, State.toggle_filter(state, "pedagogy")) |> merge_changes(state)

      assert state.filters == MapSet.new(["content", "accessibility", "equity"])

      assert length(state.filtered_warnings) == 1

      # if we dismiss the last warning in a filtered state when there are other warnings that are filtered out,
      # the UI should not select and show one of the filtered out warnings, the selection should be nil
      state =
        State.warning_dismissed(state, hd(state.filtered_warnings).id) |> merge_changes(state)

      assert state.selected == nil
    end
  end
end
