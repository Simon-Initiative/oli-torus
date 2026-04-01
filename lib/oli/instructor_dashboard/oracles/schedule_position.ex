defmodule Oli.InstructorDashboard.Oracles.SchedulePosition do
  @moduledoc """
  Returns the current schedule position for the selected dashboard scope.
  """

  use Oli.Dashboard.Oracle

  alias Oli.Dashboard.OracleContext
  alias Oli.Dashboard.Scope
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.InstructorDashboard.Oracles.Helpers

  @impl true
  def key, do: :oracle_instructor_schedule_position

  @impl true
  def version, do: 1

  @impl true
  def load(%OracleContext{} = context, opts) do
    with {:ok, section_id, %Scope{} = scope} <- Helpers.section_scope(context) do
      section = Helpers.section(section_id)
      hierarchy = SectionResourceDepot.get_delivery_resolver_full_hierarchy(section)
      scheduled_resources = scheduled_resources(section_id)
      now = Keyword.get(opts, :now, DateTime.utc_now())

      if map_size(scheduled_resources) == 0 do
        {:ok, %{has_schedule?: false}}
      else
        global_current_resource_id = choose_global_resource_id(scheduled_resources, now)

        current_item =
          hierarchy
          |> scoped_node(scope)
          |> choose_current_item(global_current_resource_id)

        {:ok, build_payload(current_item)}
      end
    end
  end

  defp scheduled_resources(section_id) do
    section_id
    |> SectionResourceDepot.retrieve_schedule()
    |> Enum.filter(&scheduled_resource?/1)
    |> Map.new(fn section_resource -> {section_resource.resource_id, section_resource} end)
  end

  defp scheduled_resource?(%SectionResource{
         start_date: start_date,
         end_date: end_date,
         hidden: hidden,
         removed_from_schedule: removed_from_schedule
       }) do
    not hidden and not removed_from_schedule and (not is_nil(start_date) or not is_nil(end_date))
  end

  defp scoped_node(hierarchy, %Scope{container_type: :course}), do: hierarchy

  defp scoped_node(hierarchy, %Scope{container_type: :container, container_id: container_id}),
    do: find_by_resource_id(hierarchy, container_id)

  defp direct_children(nil), do: []
  defp direct_children(node), do: node.children || []

  defp choose_current_item(nil, _global_current_resource_id), do: nil
  defp choose_current_item(_node, nil), do: nil

  # The schedule marker is derived from the course-wide current scheduled
  # resource first, then mapped into the currently visible scope. If the scoped
  # subtree does not contain that global position, the tile should not show a
  # local schedule marker at all.
  defp choose_current_item(node, global_current_resource_id) do
    cond do
      node.resource_id == global_current_resource_id ->
        node

      true ->
        direct_children(node)
        |> Enum.find(fn child ->
          subtree_contains_resource?(child, global_current_resource_id)
        end)
    end
  end

  defp choose_global_resource_id(scheduled_resources, now) do
    scheduled_resources
    |> Map.values()
    |> Enum.map(fn section_resource ->
      {section_resource.resource_id, normalize_range(section_resource)}
    end)
    |> Enum.reject(fn {_resource_id, range} -> is_nil(range) end)
    |> Enum.min_by(
      fn {resource_id, range} ->
        {selection_bucket(range, now), selection_distance(range, now), resource_id}
      end,
      fn -> nil end
    )
    |> case do
      {resource_id, _range} -> resource_id
      nil -> nil
    end
  end

  # Selection priority:
  # 1. A child whose range contains "now"
  # 2. Otherwise, the nearest upcoming child
  # 3. Otherwise, the most recent past child
  defp selection_bucket(range, now) do
    cond do
      within_range?(range, now) -> 0
      DateTime.compare(range.start_at, now) == :gt -> 1
      true -> 2
    end
  end

  defp selection_distance(range, now) do
    cond do
      within_range?(range, now) -> DateTime.diff(range.end_at, now, :second)
      DateTime.compare(range.start_at, now) == :gt -> DateTime.diff(range.start_at, now, :second)
      true -> DateTime.diff(now, range.end_at, :second)
    end
  end

  defp within_range?(range, now) do
    DateTime.compare(range.start_at, now) in [:lt, :eq] and
      DateTime.compare(range.end_at, now) in [:gt, :eq]
  end

  defp normalize_range(nil), do: nil

  defp normalize_range(%SectionResource{start_date: start_date, end_date: end_date})
       when is_nil(start_date) and is_nil(end_date),
       do: nil

  defp normalize_range(%SectionResource{start_date: start_date, end_date: end_date}) do
    %{start_at: start_date || end_date, end_at: end_date || start_date}
  end

  defp build_payload(nil), do: %{has_schedule?: true}

  defp build_payload(node) do
    label = "Schedule: #{node.revision.title}"

    %{
      has_schedule?: true,
      current_resource_id: node.resource_id,
      label: label,
      tooltip: label
    }
  end

  defp find_by_resource_id(node, resource_id) do
    cond do
      node.resource_id == resource_id ->
        node

      true ->
        Enum.find_value(node.children || [], fn child ->
          find_by_resource_id(child, resource_id)
        end)
    end
  end

  defp subtree_contains_resource?(node, resource_id) do
    node.resource_id == resource_id or
      Enum.any?(node.children || [], &subtree_contains_resource?(&1, resource_id))
  end
end
