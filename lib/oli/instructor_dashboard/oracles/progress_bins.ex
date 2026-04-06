defmodule Oli.InstructorDashboard.Oracles.ProgressBins do
  @moduledoc """
  Returns fixed-size progress histograms per direct child resource.
  """

  use Oli.Dashboard.Oracle

  import Ecto.Query, warn: false

  alias Oli.Dashboard.OracleContext
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Delivery.Sections.ContainedPage
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.InstructorDashboard.Oracles.Helpers
  alias Oli.Repo
  alias Oli.Resources.ResourceType

  @bins Enum.to_list(0..100//10)
  @page_type_id ResourceType.id_for_page()
  @container_type_id ResourceType.id_for_container()

  @impl true
  def key, do: :oracle_instructor_progress_bins

  @impl true
  def version, do: 2

  @impl true
  def load(%OracleContext{} = context, opts) do
    with {:ok, section_id, scope} <- Helpers.section_scope(context),
         learner_ids <- Helpers.enrolled_learner_ids(section_id),
         axis_items <- axis_items(section_id, scope, opts) do
      by_resource_bins = by_resource_bins(section_id, axis_items, learner_ids)

      {:ok,
       %{
         bin_size: 10,
         by_container_bins: container_bins(axis_items, by_resource_bins),
         by_resource_bins: by_resource_bins,
         total_students: Enum.count(learner_ids)
       }}
    end
  end

  defp axis_items(section_id, scope, opts) do
    direct_children = direct_children(section_id, scope)

    opts
    |> Keyword.get(:axis_resource_ids, Keyword.get(opts, :axis_container_ids, []))
    |> case do
      [] ->
        direct_children

      ids when is_list(ids) ->
        id_set = ids |> Enum.uniq() |> MapSet.new()
        Enum.filter(direct_children, &MapSet.member?(id_set, &1.resource_id))

      _ ->
        []
    end
  end

  defp direct_children(section_id, scope) do
    hierarchy =
      section_id
      |> Helpers.section()
      |> SectionResourceDepot.get_delivery_resolver_full_hierarchy()

    case scope.container_type do
      :course ->
        hierarchy.children || []

      :container ->
        case find_by_resource_id(hierarchy, scope.container_id) do
          nil -> []
          node -> node.children || []
        end
    end
    |> Enum.map(fn child ->
      %{
        resource_id: child.resource_id,
        resource_type_id: child.revision.resource_type_id
      }
    end)
    |> Enum.uniq_by(& &1.resource_id)
    |> Enum.sort_by(& &1.resource_id)
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

  defp by_resource_bins(_section_id, [], _learner_ids), do: %{}

  defp by_resource_bins(section_id, axis_items, learner_ids) do
    {container_items, page_items} =
      Enum.split_with(axis_items, &(&1.resource_type_id == @container_type_id))

    container_ids = Enum.map(container_items, & &1.resource_id)
    page_ids = Enum.map(page_items, & &1.resource_id)

    page_counts = page_counts(section_id, container_ids)
    container_progress = container_progress_by_student(section_id, container_ids, learner_ids)
    page_progress = page_progress_by_student(section_id, page_ids, learner_ids)

    Enum.reduce(axis_items, %{}, fn item, acc ->
      bins =
        case item.resource_type_id do
          resource_type_id when resource_type_id == @container_type_id ->
            build_bins(
              learner_ids,
              Map.get(container_progress, item.resource_id, %{}),
              Map.get(page_counts, item.resource_id, 0) > 0
            )

          resource_type_id when resource_type_id == @page_type_id ->
            build_bins(learner_ids, Map.get(page_progress, item.resource_id, %{}), true)

          _ ->
            empty_bins()
        end

      Map.put(acc, item.resource_id, bins)
    end)
  end

  defp container_bins(axis_items, by_resource_bins) do
    axis_items
    |> Enum.filter(&(&1.resource_type_id == @container_type_id))
    |> Enum.reduce(%{}, fn item, acc ->
      Map.put(acc, item.resource_id, Map.get(by_resource_bins, item.resource_id, empty_bins()))
    end)
  end

  defp build_bins(learner_ids, progress_by_learner, has_progress_source?) do
    if has_progress_source? do
      missing_learners = max(length(learner_ids) - map_size(progress_by_learner), 0)

      progress_by_learner
      |> Enum.reduce(empty_bins(), fn {_learner_id, ratio}, bins_acc ->
        Map.update!(bins_acc, bin_for_progress(ratio), &(&1 + 1))
      end)
      |> Map.update!(0, &(&1 + missing_learners))
    else
      empty_bins()
    end
  end

  defp page_counts(section_id, container_ids) do
    from(cp in ContainedPage,
      where: cp.section_id == ^section_id and cp.container_id in ^container_ids,
      group_by: cp.container_id,
      select: {cp.container_id, count(cp.id)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  defp container_progress_by_student(_section_id, _container_ids, []), do: %{}
  defp container_progress_by_student(_section_id, [], _learner_ids), do: %{}

  defp container_progress_by_student(section_id, container_ids, learner_ids) do
    page_counts_query =
      from(cp in ContainedPage,
        where: cp.section_id == ^section_id and cp.container_id in ^container_ids,
        group_by: cp.container_id,
        select: %{container_id: cp.container_id, page_count: count(cp.id)}
      )

    from(cp in ContainedPage,
      join: ra in ResourceAccess,
      on:
        cp.page_id == ra.resource_id and
          cp.section_id == ra.section_id and
          ra.user_id in ^learner_ids,
      join: pc in subquery(page_counts_query),
      on: pc.container_id == cp.container_id,
      where: cp.section_id == ^section_id and cp.container_id in ^container_ids,
      group_by: [cp.container_id, ra.user_id, pc.page_count],
      select: {
        cp.container_id,
        ra.user_id,
        fragment("SUM(?) / NULLIF(?, 0)", ra.progress, pc.page_count)
      }
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn {container_id, learner_id, ratio}, acc ->
      container_progress = Map.get(acc, container_id, %{})
      Map.put(acc, container_id, Map.put(container_progress, learner_id, ratio || 0.0))
    end)
  end

  defp page_progress_by_student(_section_id, _page_ids, []), do: %{}
  defp page_progress_by_student(_section_id, [], _learner_ids), do: %{}

  defp page_progress_by_student(section_id, page_ids, learner_ids) do
    from(ra in ResourceAccess,
      where:
        ra.section_id == ^section_id and ra.resource_id in ^page_ids and
          ra.user_id in ^learner_ids,
      select: {ra.resource_id, ra.user_id, ra.progress}
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn {page_id, learner_id, ratio}, acc ->
      page_progress = Map.get(acc, page_id, %{})
      Map.put(acc, page_id, Map.put(page_progress, learner_id, ratio || 0.0))
    end)
  end

  defp empty_bins, do: Enum.into(@bins, %{}, fn bin -> {bin, 0} end)

  defp bin_for_progress(ratio) when not is_number(ratio), do: 0
  defp bin_for_progress(ratio) when ratio <= 0.0, do: 0
  defp bin_for_progress(ratio) when ratio >= 1.0, do: 100

  defp bin_for_progress(ratio) do
    ratio
    |> Kernel.*(100.0)
    |> Kernel./(10.0)
    |> Float.ceil()
    |> trunc()
    |> Kernel.*(10)
    |> min(100)
  end
end
