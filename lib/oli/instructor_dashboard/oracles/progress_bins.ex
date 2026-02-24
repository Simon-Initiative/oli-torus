defmodule Oli.InstructorDashboard.Oracles.ProgressBins do
  @moduledoc """
  Returns fixed-size progress histograms per direct child container.
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

  @impl true
  def key, do: :oracle_instructor_progress_bins

  @impl true
  def version, do: 1

  @impl true
  def load(%OracleContext{} = context, opts) do
    with {:ok, section_id, scope} <- Helpers.section_scope(context),
         learner_ids <- Helpers.enrolled_learner_ids(section_id),
         container_ids <- axis_container_ids(section_id, scope, opts) do
      {:ok,
       %{
         bin_size: 10,
         by_container_bins: by_container_bins(section_id, container_ids, learner_ids),
         total_students: Enum.count(learner_ids)
       }}
    end
  end

  defp axis_container_ids(section_id, scope, opts) do
    opts
    |> Keyword.get(:axis_container_ids, [])
    |> case do
      [] -> derive_axis_container_ids(section_id, scope)
      ids when is_list(ids) -> ids |> Enum.uniq() |> Enum.sort()
      _ -> []
    end
  end

  defp derive_axis_container_ids(section_id, scope) do
    container_type_id = ResourceType.id_for_container()

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
    |> Enum.filter(&(&1.revision.resource_type_id == container_type_id))
    |> Enum.map(& &1.resource_id)
    |> Enum.uniq()
    |> Enum.sort()
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

  defp by_container_bins(_section_id, [], _learner_ids), do: %{}

  defp by_container_bins(section_id, container_ids, learner_ids) do
    page_counts = page_counts(section_id, container_ids)
    progress = progress_by_student(section_id, container_ids, learner_ids)

    Enum.reduce(container_ids, %{}, fn container_id, acc ->
      bins =
        learner_ids
        |> Enum.reduce(empty_bins(), fn learner_id, bins_acc ->
          ratio =
            progress
            |> Map.get(container_id, %{})
            |> Map.get(learner_id, 0.0)

          Map.update!(bins_acc, bin_for_progress(ratio), &(&1 + 1))
        end)

      case Map.get(page_counts, container_id, 0) do
        0 -> Map.put(acc, container_id, empty_bins())
        _ -> Map.put(acc, container_id, bins)
      end
    end)
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

  defp progress_by_student(_section_id, _container_ids, []), do: %{}

  defp progress_by_student(section_id, container_ids, learner_ids) do
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
