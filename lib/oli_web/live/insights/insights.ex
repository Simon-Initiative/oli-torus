defmodule OliWeb.Insights do
  use OliWeb, :live_view

  alias OliWeb.Insights.{TableHeader, TableRow}
  alias Oli.Authoring.Course
  alias Oli.Utils
  alias CSV

  def mount(_params, %{"project_slug" => project_slug} = _session, socket) do
    by_activity_rows = Oli.Analytics.ByActivity.query_against_project_slug(project_slug)
    project = Course.get_project_by_slug(project_slug)

    parent_pages =
      Enum.map(by_activity_rows, fn r -> r.slice.resource_id end)
      |> parent_pages(project_slug)

    {:ok,
     assign(socket,
       project: project,
       by_page_rows: nil,
       by_activity_rows: by_activity_rows,
       by_objective_rows: nil,
       parent_pages: parent_pages,
       selected: :by_activity,
       active_rows: apply_filter_sort(:by_activity, by_activity_rows, "", "title", :asc),
       query: "",
       sort_by: "title",
       sort_order: :asc,
       title: "Insights | " <> project.title
     )}
  end

  defp parent_pages(resource_ids, project_slug) do
    publication = Oli.Publishing.project_working_publication(project_slug)
    Oli.Publishing.determine_parent_pages(resource_ids, publication.id)
  end

  defp arrange_rows_into_objective_hierarchy(rows) do
    by_id = Enum.reduce(rows, %{}, fn r, m -> Map.put(m, r.slice.resource_id, r) end)

    parents =
      Enum.reduce(rows, %{}, fn r, m ->
        Enum.reduce(r.slice.children, m, fn id, m -> Map.put(m, id, r.slice.resource_id) end)
      end)

    Enum.filter(rows, fn r -> !Map.has_key?(parents, r.slice.resource_id) end)
    |> Enum.map(fn parent ->
      child_rows =
        Enum.map(parent.slice.children, fn c -> Map.get(by_id, c) |> Map.put(:is_child, true) end)

      Map.put(parent, :child_rows, child_rows)
    end)
  end

  defp get_active_original(assigns) do
    case assigns.selected do
      :by_page -> assigns.by_page_rows
      :by_activity -> assigns.by_activity_rows
      _ -> assigns.by_objective_rows
    end
  end

  def render(assigns) do
    ~H"""
    <ul class="nav nav-pills">
      <li class="nav-item my-2 mr-2">
        <button {is_disabled(@selected, :by_activity)} class="btn btn-primary" phx-click="by-activity">By Activity</button>
      </li>
      <li class="nav-item my-2 mr-2">
        <button {is_disabled(@selected, :by_page)} class="btn btn-primary" phx-click="by-page">
          <%= if is_loading?(assigns) and @selected == :by_page do %>
            <span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>
          <% end %>
          By Page
        </button>
      </li>
      <li class="nav-item my-2 mr-2">
        <button {is_disabled(@selected, :by_objective)} class="btn btn-primary" phx-click="by-objective">
          <%= if is_loading?(assigns) and @selected == :by_objective do %>
            <span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>
          <% end %>
          By Objective
        </button>
      </li>
    </ul>
    <div class="card">
      <div class="card-header">
        <form phx-change="search">
          <input type="text" class="form-control" name="query" value={@query} placeholder="Search by title..." />
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

        <%= if !is_loading?(assigns) do %>
          <table class="table table-sm">
            <%= live_component TableHeader, assigns %>
            <tbody>
              <%= for row <- @active_rows do %>
                <%= live_component TableRow, row: row, parent_pages: assigns.parent_pages, project: assigns.project, selected: @selected %>
              <% end %>
            </tbody>
          </table>
        <% end %>

      </div>
    </div>
    """
  end

  defp is_loading?(assigns) do
    is_nil(assigns.active_rows)
  end

  defp apply_filter_sort(:by_objective, rows, query, sort_by, sort_order) do
    filter(rows, query)
    |> sort(sort_by, sort_order)
    |> Enum.reduce([], fn p, all ->
      p.child_rows ++ [p] ++ all
    end)
    |> Enum.reverse()
  end

  defp apply_filter_sort(_, rows, query, sort_by, sort_order) do
    filter(rows, query)
    |> sort(sort_by, sort_order)
  end

  defp filter(rows, query) do
    rows |> Enum.filter(&String.match?(&1.slice.title, ~r/#{String.trim(query)}/i))
  end

  # data splits
  def handle_event("by-activity", _event, socket) do
    active_rows =
      apply_filter_sort(
        :by_activity,
        socket.assigns.by_activity_rows,
        socket.assigns.query,
        socket.assigns.sort_by,
        socket.assigns.sort_order
      )

    {:noreply, assign(socket, selected: :by_activity, active_rows: active_rows)}
  end

  def handle_event("by-page", _event, socket) do
    active_rows =
      if is_nil(socket.assigns.by_page_rows) do
        send(self(), :init_by_page)
        nil
      else
        apply_filter_sort(
          :by_page,
          socket.assigns.by_page_rows,
          socket.assigns.query,
          socket.assigns.sort_by,
          socket.assigns.sort_order
        )
      end

    {:noreply, assign(socket, selected: :by_page, active_rows: active_rows)}
  end

  def handle_event("by-objective", _event, socket) do
    active_rows =
      if is_nil(socket.assigns.by_objective_rows) do
        send(self(), :init_by_objective)
        nil
      else
        apply_filter_sort(
          :by_objective,
          socket.assigns.by_objective_rows,
          socket.assigns.query,
          socket.assigns.sort_by,
          socket.assigns.sort_order
        )
      end

    {:noreply, assign(socket, selected: :by_objective, active_rows: active_rows)}
  end

  # search
  def handle_event("search", %{"query" => query}, socket) do
    active_rows =
      apply_filter_sort(
        socket.assigns.selected,
        get_active_original(socket.assigns),
        query,
        socket.assigns.sort_by,
        socket.assigns.sort_order
      )

    {:noreply, assign(socket, query: query, active_rows: active_rows)}
  end

  # sorting

  # CLick same column -> reverse sort order
  def handle_event(
        "sort",
        %{"sort-by" => column} = event,
        %{assigns: %{sort_by: sort_by, sort_order: :asc}} = socket
      )
      when column == sort_by do
    {:noreply,
     if click_or_enter_key?(event) do
       active_rows =
         apply_filter_sort(
           socket.assigns.selected,
           get_active_original(socket.assigns),
           socket.assigns.query,
           socket.assigns.sort_by,
           :desc
         )

       assign(socket, sort_by: sort_by, sort_order: :desc, active_rows: active_rows)
     else
       socket
     end}
  end

  def handle_event(
        "sort",
        %{"sort-by" => column} = event,
        %{assigns: %{sort_by: sort_by, sort_order: :desc}} = socket
      )
      when column == sort_by do
    {:noreply,
     if click_or_enter_key?(event) do
       active_rows =
         apply_filter_sort(
           socket.assigns.selected,
           get_active_original(socket.assigns),
           socket.assigns.query,
           socket.assigns.sort_by,
           :asc
         )

       assign(socket, sort_by: sort_by, sort_order: :asc, active_rows: active_rows)
     else
       socket
     end}
  end

  # Click new column
  def handle_event("sort", %{"sort-by" => column} = event, socket) do
    {:noreply,
     if click_or_enter_key?(event) do
       active_rows =
         apply_filter_sort(
           socket.assigns.selected,
           get_active_original(socket.assigns),
           socket.assigns.query,
           column,
           socket.assigns.sort_order
         )

       assign(socket, sort_by: column, active_rows: active_rows)
     else
       socket
     end}
  end

  def handle_info(:init_by_page, socket) do
    by_page_rows = Oli.Analytics.ByPage.query_against_project_slug(socket.assigns.project.slug)

    active_rows =
      apply_filter_sort(
        :by_page,
        by_page_rows,
        socket.assigns.query,
        socket.assigns.sort_by,
        socket.assigns.sort_order
      )

    {:noreply, assign(socket, by_page_rows: by_page_rows, active_rows: active_rows)}
  end

  def handle_info(:init_by_objective, socket) do
    by_objective_rows =
      Oli.Analytics.ByObjective.query_against_project_slug(socket.assigns.project.slug)
      |> arrange_rows_into_objective_hierarchy()

    active_rows =
      apply_filter_sort(
        :by_objective,
        by_objective_rows,
        socket.assigns.query,
        socket.assigns.sort_by,
        socket.assigns.sort_order
      )

    {:noreply, assign(socket, by_objective_rows: by_objective_rows, active_rows: active_rows)}
  end

  defp click_or_enter_key?(event) do
    event["key"] == nil or event["key"] == "Enter"
  end

  defp sort(rows, "title", :asc), do: rows |> Enum.sort(&(&1.slice.title > &2.slice.title))
  defp sort(rows, "title", :desc), do: rows |> Enum.sort(&(&1.slice.title <= &2.slice.title))

  defp sort(rows, sort_by, :asc) do
    sort_by_as_atom = String.to_existing_atom(sort_by)
    Enum.sort(rows, &(&1[sort_by_as_atom] > &2[sort_by_as_atom]))
  end

  defp sort(rows, sort_by, :desc) do
    sort_by_as_atom = String.to_existing_atom(sort_by)
    Enum.sort(rows, &(&1[sort_by_as_atom] <= &2[sort_by_as_atom]))
  end

  defp is_disabled(selected, title) do
    if selected == title do
      [disabled: true]
    else
      []
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
      "Part Attempt ID",
      "Activity ID",
      "Page ID",
      "Objective ID",
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
      "Activity Content",
      "Section Title",
      "Section Slug",
      "Date Created",
      "Student ID",
      "Activity Attempt ID",
      "Resource Attempt ID"
    ]

    [
      [
        snapshots_title_row
        | Oli.Analytics.Common.snapshots_for_project(project_slug)
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
        case Map.get(h, :activity) do
          nil -> slice.title
          %{title: nil} -> slice.title
          %{title: title} -> title
          _ -> slice.title
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
