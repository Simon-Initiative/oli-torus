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
        current_item =
          hierarchy
          |> scoped_node(scope)
          |> direct_children()
          |> choose_current_item(scheduled_resources, now)

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

  defp choose_current_item([], _scheduled_resources, _now), do: nil

  # The schedule marker answers "where are we?" for the current scope. We resolve
  # it by scoring the visible direct children of the scoped node against the
  # current time, using each child's aggregated schedule range.
  defp choose_current_item(children, scheduled_resources, now),
    do: choose_by_range(children, scheduled_resources, now)

  defp choose_by_range(children, scheduled_resources, now) do
    children
    |> Enum.map(fn child -> {child, aggregate_range(child, scheduled_resources)} end)
    |> Enum.reject(fn {_child, range} -> is_nil(range) end)
    |> Enum.sort_by(fn {child, range} ->
      {selection_bucket(range, now), selection_distance(range, now), child.resource_id}
    end)
    |> List.first()
    |> case do
      {child, _range} -> child
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

  # Container-level schedule position is derived from scheduled descendants, so a
  # unit or module becomes "current" when any scheduled work inside its subtree
  # makes its overall range current or nearest.
  defp aggregate_range(node, scheduled_resources) do
    [self_range(node, scheduled_resources) | descendant_ranges(node, scheduled_resources)]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] ->
        nil

      ranges ->
        %{
          start_at:
            ranges
            |> Enum.min_by(& &1.start_at, fn left, right ->
              DateTime.compare(left, right) != :gt
            end)
            |> Map.fetch!(:start_at),
          end_at:
            ranges
            |> Enum.max_by(& &1.end_at, fn left, right ->
              DateTime.compare(left, right) != :lt
            end)
            |> Map.fetch!(:end_at)
        }
    end
  end

  defp descendant_ranges(node, scheduled_resources) do
    Enum.flat_map(node.children || [], fn child ->
      [aggregate_range(child, scheduled_resources)]
    end)
  end

  defp self_range(node, scheduled_resources) do
    node.resource_id
    |> then(&Map.get(scheduled_resources, &1))
    |> normalize_range()
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
end
