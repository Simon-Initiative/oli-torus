defmodule OliWeb.Insights do
  use Phoenix.LiveView
  alias OliWeb.Insights.{TableHeader, TableRow}
  alias Oli.Authoring.Course
  alias Oli.Utils
  alias CSV
  alias Oli.Activities

  def mount(_params, %{"project_slug" => project_slug} = _session, socket) do
    by_activity_rows = Oli.Analytics.ByActivity.query_against_project_slug(project_slug)
    project = Course.get_project_by_slug(project_slug)

    parent_pages =
      Enum.map(by_activity_rows, fn r -> r.slice.resource_id end)
      |> parent_pages(project_slug)

    {:ok,
     assign(socket,
       project: project,
       by_page_rows: Oli.Analytics.ByPage.query_against_project_slug(project_slug),
       by_activity_rows: by_activity_rows,
       by_objective_rows: Oli.Analytics.ByObjective.query_against_project_slug(project_slug),
       parent_pages: parent_pages,
       selected: :by_activity,
       query: "",
       sort_by: "title",
       sort_order: :asc
     )}
  end

  defp parent_pages(resource_ids, project_slug) do
    publication = Oli.Publishing.project_working_publication(project_slug)
    Oli.Publishing.determine_parent_pages(resource_ids, publication.id)
  end

  def render(assigns) do
    ~L"""
    <ul class="nav nav-pills">
      <li class="nav-item my-2 mr-2">
        <button <%= is_disabled(@selected, :by_activity) %> class="btn btn-primary" phx-click="by-activity">By Activity</button>
      </li>
      <li class="nav-item my-2 mr-2">
        <button <%= is_disabled(@selected, :by_page) %> class="btn btn-primary" phx-click="by-page">By Page</button>
      </li>
      <li class="nav-item my-2 mr-2">
        <button <%= is_disabled(@selected, :by_objective) %> class="btn btn-primary" phx-click="by-objective">By Objective</button>
      </li>
    </ul>
    <div class="card text-center">
      <div class="card-header">
        <form phx-change="search">
          <input type="text" class="form-control" name="query" value="<%= @query %>" placeholder="Search by title..." />
        </form>
      </div>
      <div class="card-body">
        <h5 class="card-title">
          Viewing analytics by <%= case @selected do
          :by_page -> "page"
          :by_activity -> "activity"
          :by_objective -> "objective"
          _ -> "activity"
        end %></h5>
        <table class="table">
          <%= live_component TableHeader, assigns %>
          <tbody>
            <%= for row <- active_rows(assigns) do %>
              <%= live_component TableRow, row: row, parent_pages: assigns.parent_pages, project: assigns.project, selected: @selected %>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp active_rows(assigns) do
    case assigns.selected do
      :by_page -> assigns.by_page_rows
      :by_activity -> assigns.by_activity_rows
      :by_objective -> assigns.by_objective_rows
      _ -> assigns.by_activity_rows
    end
    |> filter(assigns.query)
    |> sort(assigns.sort_by, assigns.sort_order)
  end

  defp filter(rows, query) do
    rows |> Enum.filter(&String.match?(&1.slice.title, ~r/#{String.trim(query)}/i))
  end

  # data splits
  def handle_event("by-activity", _event, socket) do
    {:noreply, assign(socket, :selected, :by_activity)}
  end

  def handle_event("by-page", _event, socket) do
    {:noreply, assign(socket, :selected, :by_page)}
  end

  def handle_event("by-objective", _event, socket) do
    {:noreply, assign(socket, :selected, :by_objective)}
  end

  # search
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, query: query)}
  end

  # sorting

  # CLick same column -> reverse sort order
  def handle_event(
        "sort",
        %{"sort-by" => column} = _event,
        %{assigns: %{sort_by: sort_by, sort_order: :asc}} = socket
      )
      when column == sort_by do
    {:noreply, assign(socket, sort_by: sort_by, sort_order: :desc)}
  end

  def handle_event(
        "sort",
        %{"sort-by" => column} = _event,
        %{assigns: %{sort_by: sort_by, sort_order: :desc}} = socket
      )
      when column == sort_by do
    {:noreply, assign(socket, sort_by: sort_by, sort_order: :asc)}
  end

  # Click new column
  def handle_event("sort", %{"sort-by" => column} = _event, socket) do
    {:noreply, assign(socket, sort_by: column)}
  end

  defp sort(rows, "title", :asc), do: rows |> Enum.sort(&(&1.slice.title > &2.slice.title))
  defp sort(rows, "title", :desc), do: rows |> Enum.sort(&(&1.slice.title <= &2.slice.title))
  defp sort(rows, sort_by, :asc), do: rows |> Enum.sort(&(&1[sort_by] > &2[sort_by]))
  defp sort(rows, sort_by, :desc), do: rows |> Enum.sort(&(&1[sort_by] <= &2[sort_by]))

  defp is_disabled(selected, title) do
    if selected == title do
      "disabled"
    else
      ""
    end
  end

  def export(project) do
    filenames =
      ["raw_analytics.tsv", "by_page.tsv", "by_activity.tsv", "by_objective.tsv"]
      # CSV Encoder expects charlists for filenames, not strings
      |> Enum.map(&String.to_charlist(&1))

    analytics =
      raw_snapshot_data(project.slug)
      |> Enum.concat(derived_analytics_data(project.slug))
      |> Enum.map(&CSV.encode(&1, separator: ?\t))
      |> Enum.map(&Enum.join(&1, ""))

    Enum.zip(filenames, analytics)
    # Convert to tuples of {filename, CSV table rows}
    |> Enum.map(&{elem(&1, 0), elem(&1, 1)})
    |> Utils.zip("analytics.zip")
  end

  def raw_snapshot_data(project_slug) do
    snapshots_title_row = [
      "Activity Title",
      "Activity Type",
      "Objective Title",
      "Attempt Number",
      "Graded?",
      "Correct?",
      "Activity Score",
      "Activity Out Of",
      "Hints Requested",
      "Part Score",
      "Part Out Of",
      "Student Response",
      "Feedback",
      "Section Title",
      "Section Slug",
      "Date Created"
    ]

    [
      [
        snapshots_title_row
        | Oli.Analytics.Common.snapshots_for_project(project_slug)
          |> Enum.map(
            &(&1
              # Query returns a list of fields
              # Get activity type
              |> List.replace_at(1, Activities.get_registration!(Enum.at(&1, 1)).title)
              # JSON format student response
              |> List.replace_at(11, Utils.pretty(Enum.at(&1, 11)))
              # JSON format feedback
              |> List.replace_at(12, Utils.pretty(Enum.at(&1, 12)))
              # JSON format date
              |> List.replace_at(15, Utils.format_datetime(Enum.at(&1, 15))))
          )
      ]
    ]
  end

  def derived_analytics_data(project_slug) do
    analytics_title_row = [
      "Resource Title",
      "Activity Title",
      "Number of Attempts",
      "Relative Difficulty",
      "Eventually Correct",
      "First Try Correct"
    ]

    [
      Oli.Analytics.ByPage.query_against_project_slug(project_slug),
      Oli.Analytics.ByActivity.query_against_project_slug(project_slug),
      Oli.Analytics.ByObjective.query_against_project_slug(project_slug)
    ]
    |> Enum.map(&[analytics_title_row | extract_analytics(&1)])
  end

  def extract_analytics([
        %{
          slice: slice,
          number_of_attempts: number_of_attempts,
          relative_difficulty: relative_difficulty,
          eventually_correct: eventually_correct,
          first_try_correct: first_try_correct
        } = h
        | t
      ]) do
    [
      [
        slice.title,
        if !Map.has_key?(h, :activity) do
          slice.title
        else
          h.activity.title
        end,
        if is_nil(number_of_attempts) do
          "No attempts"
        else
          Integer.to_string(number_of_attempts)
        end,
        if is_nil(relative_difficulty) do
          ""
        else
          Float.to_string(truncate(relative_difficulty))
        end,
        if is_nil(eventually_correct) do
          ""
        else
          format_percent(eventually_correct)
        end,
        if is_nil(first_try_correct) do
          ""
        else
          format_percent(first_try_correct)
        end
      ]
      | extract_analytics(t)
    ]
  end

  def extract_analytics([]), do: []

  def truncate(float_or_nil) when is_nil(float_or_nil), do: nil
  def truncate(float_or_nil) when is_float(float_or_nil), do: Float.round(float_or_nil, 2)

  def format_percent(float_or_nil) when is_nil(float_or_nil), do: nil

  def format_percent(float_or_nil) when is_float(float_or_nil),
    do: "#{round(100 * float_or_nil)}%"
end
