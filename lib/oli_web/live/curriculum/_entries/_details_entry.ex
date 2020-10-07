defmodule OliWeb.Curriculum.DetailsEntry do

  @moduledoc """
  Curriculum item entry component.
  """

  use Phoenix.LiveComponent

  # For the given list of activity ids, find and return the set of objective revisions
  # that these activities have attached.
  defp determine_objectives(activity_ids, activity_map, objective_map) do

    Enum.map(activity_ids, fn id -> Map.get(activity_map, id) end)
    |> Enum.reduce(MapSet.new(), fn %{objectives: objectives}, map_set ->

      Enum.map(objectives, fn {_, ids} -> ids end)
      |> List.flatten()
      |> MapSet.new()
      |> MapSet.union(map_set)

    end)
    |> MapSet.to_list()
    |> Enum.map(fn id -> Map.get(objective_map, id) end)
  end

  defp render_objectives_count(assigns, objectives) do

    count = length(objectives)

    objs = if count == 1 do "objective" else "objectives" end

    ~L"""
    <%= count %> <%= objs %>
    """
  end

  defp render_counts(assigns, objectives) do

    count = length(assigns.activity_ids)

    type = if assigns.page.graded do "summative" else "practice" end
    activities = if count == 1 do "activity" else "activities" end
    muted = if assigns.selected do "" else "text-muted" end

    if (count > 0) do
      ~L"""
      <div><small class="<%= muted %>"><%= count %> <%= type %> <%= activities %> targeting
        <%= render_objectives_count(assigns, objectives) %></small>
      </div>
      """
    else
      ~L"""
      <small class="<%= muted %>">No <%= type %> activities</small>
      """
    end

  end

  defp render_objectives(assigns, objectives) do
    ~L"""
    <div class="targeted-objectives">

      <%= for %{title: title} <- objectives do %>
        <div class="objective"><%= title %></div>
      <% end %>

    </div>
    """


  end

  def render(assigns) do

    active_class = if assigns.selected do "active" else "" end

    count = length(assigns.activity_ids)
    objectives = if count > 0 do
      determine_objectives(assigns.activity_ids, assigns.activity_map, assigns.objective_map)
    else
      []
    end


    ~L"""
    <div
      tabindex="0"
      phx-keydown="keydown"
      id="<%= @page.resource_id %>"
      draggable="true"
      phx-click="select"
      phx-value-slug="<%= @page.slug %>"
      phx-value-index="<%= assigns.index %>"
      data-drag-index="<%= assigns.index %>"
      phx-hook="DragSource"
      class="p-1 d-flex justify-content-start curriculum-entry <%= active_class %>">

      <div class="drag-handle">
        <div class="grip"></div>
      </div>

      <div class="mt-1 ml-2 mr-2 mb-2 text-truncate" style="width: 100%;">

        <div class="d-flex justify-content-between align-items-top">
            <%= @page.title %>
          <%= render_counts(assigns, objectives) %>
        </div>

        <div>
          <%= render_objectives(assigns, objectives) %>
        </div>
      </div>

    </div>
    """
  end
end
