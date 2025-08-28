defmodule OliWeb.Curriculum.LearningSummary do
  @moduledoc """
  Curriculum item entry component.
  """

  use OliWeb, :html
  import OliWeb.Curriculum.Utils

  defp determine_activities(activity_ids, activity_map) do
    Enum.map(activity_ids, fn id -> Map.get(activity_map, id) end)
    |> Enum.filter(fn r -> !is_nil(r) end)
  end

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
    |> Enum.filter(fn r -> !is_nil(r) end)
  end

  defp render_activities(assigns, activities) do
    assigns =
      assigns
      |> assign(
        :type,
        if assigns.child.graded do
          "summative"
        else
          "formative"
        end
      )
      |> assign(:count, length(activities))
      |> assign(:activities, activities)

    ~H"""
    <small>
      <%= if @count == 0 do %>
        No {@type} activities
      <% else %>
        <%= for %{title: title} <- @activities do %>
          <div>
            {title}
          </div>
        <% end %>
      <% end %>
    </small>
    """
  end

  defp render_objectives(assigns, objectives) do
    assigns =
      assigns
      |> assign(:objectives, objectives)

    ~H"""
    <%= if Enum.count(@objectives) > 0 do %>
      <div class="targeted-objectives">
        <%= for %{title: title} <- @objectives do %>
          <div class="objective">
            <small>
              {title}
            </small>
          </div>
        <% end %>
      </div>
    <% else %>
      <small class="no-objectives">
        No targeted objectives
      </small>
    <% end %>
    """
  end

  attr(:child, :map, required: true)
  attr(:activity_ids, :list, required: true)
  attr(:activity_map, :map, required: true)
  attr(:objective_map, :map, required: true)

  def render(assigns) do
    ~H"""
    <div>
      <%= if !is_container?(@child) do %>
        <div class="col-span-4 entry-section">
          {render_objectives(
            assigns,
            determine_objectives(@activity_ids, @activity_map, @objective_map)
          )}
        </div>
        <div class="col-span-4 entry-section">
          {render_activities(assigns, determine_activities(@activity_ids, @activity_map))}
        </div>
      <% else %>
        <div></div>
      <% end %>
    </div>
    """
  end
end
