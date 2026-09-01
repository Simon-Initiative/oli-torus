defmodule Oli.Delivery.Proficiency.Naive do
  @moduledoc """
  Proficiency provider for the legacy first-attempt model.

  This module owns the `ResourceSummary` coupling, including the raw four-value
  tuple retained for compatibility. New callers receive canonical estimates;
  the tuple must never be interpreted as an LKT-AOA state.
  """

  import Ecto.Query

  alias Oli.Analytics.Summary.ResourceSummary
  alias Oli.Delivery.Proficiency.{Aggregate, Estimate, Telemetry}
  alias Oli.Delivery.Sections.ContainedPage
  alias Oli.Delivery.Sections.{Section, SectionResourceDepot}
  alias Oli.Repo
  alias Oli.Resources.ResourceType

  @minimum_attempts 3

  # ContainedObjective remains the compatibility authority for naive dashboards;
  # LKT-AOA uses only activity-derived SectionResource membership.
  def objective_ids_for_scope(%Section{id: section_id}, scope) do
    container_id = if scope == :course, do: nil, else: elem(scope, 1)
    {:ok, Oli.Delivery.Sections.get_section_contained_objectives(section_id, container_id)}
  end

  def page_ids(%Section{id: section_id}) do
    page_type_id = ResourceType.id_for_page()

    ids =
      from(summary in ResourceSummary,
        where:
          summary.section_id == ^section_id and summary.project_id == -1 and
            summary.resource_type_id == ^page_type_id,
        select: summary.resource_id,
        distinct: true
      )
      |> Repo.all()

    {:ok, ids}
  end

  def user_ids_for_objectives(%Section{id: section_id}, objective_ids) do
    objective_type_id = ResourceType.id_for_objective()

    ids =
      from(summary in ResourceSummary,
        where:
          summary.section_id == ^section_id and summary.project_id == -1 and
            summary.resource_type_id == ^objective_type_id and
            summary.resource_id in ^objective_ids and
            summary.user_id != -1,
        select: summary.user_id,
        distinct: true
      )
      |> Repo.all()

    {:ok, ids}
  end

  def user_ids_for_scopes(%Section{id: section_id} = section, scopes, opts) do
    with {:ok, membership} <- page_membership(section, scopes, opts) do
      page_ids = membership |> Map.values() |> Enum.reduce(MapSet.new(), &MapSet.union/2)
      page_type_id = ResourceType.id_for_page()

      ids =
        from(summary in ResourceSummary,
          where:
            summary.section_id == ^section_id and summary.project_id == -1 and
              summary.resource_type_id == ^page_type_id and
              summary.resource_id in ^MapSet.to_list(page_ids) and summary.user_id != -1,
          select: summary.user_id,
          distinct: true
        )
        |> Repo.all()

      {:ok, ids}
    end
  end

  def labels_for_pages(%Section{id: section_id}, page_ids, _user_ids) do
    page_type_id = ResourceType.id_for_page()

    labels =
      from(summary in ResourceSummary,
        where:
          summary.section_id == ^section_id and summary.project_id == -1 and
            summary.resource_type_id == ^page_type_id and summary.resource_id in ^page_ids and
            summary.user_id == -1,
        select: {
          summary.resource_id,
          summary.num_first_attempts_correct,
          summary.num_first_attempts
        }
      )
      |> Repo.all()
      |> Map.new(fn {page_id, correct, attempts} ->
        score = if attempts == 0, do: nil, else: (correct + 0.2 * (attempts - correct)) / attempts
        {page_id, label_string(label(score, attempts))}
      end)

    {:ok, labels}
  end

  def label_for_score(_section, score, attempt_count),
    do: score |> label(attempt_count) |> label_string()

  def estimates_for_scopes(%Section{id: section_id} = section, user_ids, scopes, opts) do
    user_ids = normalize_ids(user_ids)

    with {:ok, membership} <- page_membership(section, scopes, opts) do
      page_ids = membership |> Map.values() |> Enum.reduce(MapSet.new(), &MapSet.union/2)
      rows = read_page_summaries(section_id, user_ids, MapSet.to_list(page_ids))

      {:ok,
       Map.new(membership, fn {scope, scope_page_ids} ->
         {scope,
          Map.new(user_ids, fn user_id ->
            values = Enum.map(scope_page_ids, &Map.get(rows, {user_id, &1}, {0, 0}))
            {user_id, scope_estimate(section_id, user_id, values)}
          end)}
       end)}
    end
  end

  defp page_membership(section, scopes, opts) do
    case Keyword.fetch(opts, :page_membership) do
      {:ok, membership} -> {:ok, membership}
      :error -> persisted_page_membership(section, scopes)
    end
  end

  defp persisted_page_membership(%Section{id: section_id} = section, scopes) do
    {:ok, all_page_ids} = page_ids(section)

    container_ids =
      Enum.flat_map(scopes, fn
        {:container, id} -> [id]
        _ -> []
      end)

    contained_pages =
      from(cp in ContainedPage,
        where: cp.section_id == ^section_id and cp.container_id in ^container_ids,
        select: {cp.container_id, cp.page_id}
      )
      |> Repo.all()
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    {:ok,
     Map.new(scopes, fn
       :course ->
         {:course, MapSet.new(all_page_ids)}

       {:page, page_id} = scope ->
         {scope, MapSet.new([page_id])}

       {:container, container_id} = scope ->
         {scope, MapSet.new(Map.get(contained_pages, container_id, []))}
     end)}
  end

  def objective_aggregates(%Section{} = section, objective_ids, opts) do
    aggregate_estimates(section, objective_ids, opts, &estimates_for_objectives/4)
  end

  def scope_aggregates(%Section{} = section, scopes, opts) do
    aggregate_estimates(section, scopes, opts, &estimates_for_scopes/4)
  end

  @doc "Bulk-reads canonical naive estimates for the requested learners and objectives."
  def estimates_for_objectives(%Section{id: section_id}, user_ids, objective_ids, _opts) do
    user_ids = normalize_ids(user_ids)
    objective_ids = normalize_ids(objective_ids)

    Telemetry.span(
      :naive,
      :direct_objective,
      %{requested_user_count: length(user_ids), requested_objective_count: length(objective_ids)},
      fn ->
        objective_sources = objective_sources(section_id, objective_ids)
        source_ids = objective_sources |> Map.values() |> List.flatten() |> Enum.uniq()
        rows = read_summaries(section_id, user_ids, source_ids)

        estimates =
          Map.new(objective_ids, fn objective_id ->
            source_ids = Map.fetch!(objective_sources, objective_id)

            {objective_id,
             Map.new(user_ids, fn user_id ->
               values =
                 source_ids
                 |> Enum.map(&Map.get(rows, {user_id, &1}))
                 |> Enum.reject(&is_nil/1)
                 |> sum_summary_values()

               {user_id, estimate(section_id, user_id, objective_id, values)}
             end)}
          end)

        {:ok, estimates}
      end
    )
  end

  defp objective_sources(_section_id, []), do: %{}

  defp objective_sources(section_id, objective_ids) do
    effective_children =
      section_id
      |> SectionResourceDepot.objectives_with_effective_children_for(objective_ids)
      |> Map.new(&{&1.resource_id, normalize_ids(List.wrap(&1.children))})

    Map.new(objective_ids, fn objective_id ->
      case Map.get(effective_children, objective_id, []) do
        [] -> {objective_id, [objective_id]}
        child_ids -> {objective_id, child_ids}
      end
    end)
  end

  defp sum_summary_values([]), do: nil

  defp sum_summary_values(values) do
    Enum.reduce(values, {0, 0}, fn {correct, attempts}, {total_correct, total_attempts} ->
      {total_correct + correct, total_attempts + attempts}
    end)
  end

  defp read_summaries(_section_id, [], _objective_ids), do: %{}
  defp read_summaries(_section_id, _user_ids, []), do: %{}

  defp read_summaries(section_id, user_ids, objective_ids) do
    objective_type_id = ResourceType.id_for_objective()

    from(summary in ResourceSummary,
      where:
        summary.section_id == ^section_id and summary.project_id == -1 and
          summary.resource_type_id == ^objective_type_id and summary.user_id in ^user_ids and
          summary.resource_id in ^objective_ids,
      select: {
        summary.user_id,
        summary.resource_id,
        summary.num_first_attempts_correct,
        summary.num_first_attempts
      }
    )
    |> Repo.all()
    |> Map.new(fn {user_id, objective_id, correct, first_attempts} ->
      {{user_id, objective_id}, {correct, first_attempts}}
    end)
  end

  defp read_page_summaries(_section_id, [], _page_ids), do: %{}
  defp read_page_summaries(_section_id, _user_ids, []), do: %{}

  defp read_page_summaries(section_id, user_ids, page_ids) do
    page_type_id = ResourceType.id_for_page()

    from(summary in ResourceSummary,
      where:
        summary.section_id == ^section_id and summary.project_id == -1 and
          summary.resource_type_id == ^page_type_id and summary.user_id in ^user_ids and
          summary.resource_id in ^page_ids,
      select: {
        summary.user_id,
        summary.resource_id,
        summary.num_first_attempts_correct,
        summary.num_first_attempts
      }
    )
    |> Repo.all()
    |> Map.new(fn {user_id, page_id, correct, attempts} ->
      {{user_id, page_id}, {correct, attempts}}
    end)
  end

  @doc "Returns the exact legacy ResourceSummary tuple map used by Metrics adapters."
  def raw_proficiency_per_learning_objective(section_id, opts \\ []) do
    objective_type_id = ResourceType.id_for_objective()

    objective_filter =
      if opts[:objective_ids],
        do: dynamic([summary], summary.resource_id in ^opts[:objective_ids]),
        else: true

    student_filter =
      if opts[:student_id],
        do: dynamic([summary], summary.user_id == ^opts[:student_id]),
        else: dynamic([summary], summary.user_id == -1)

    from(summary in ResourceSummary,
      where:
        summary.section_id == ^section_id and summary.project_id == -1 and
          summary.resource_type_id == ^objective_type_id,
      where: ^objective_filter,
      where: ^student_filter,
      select: {
        summary.resource_id,
        {
          summary.num_first_attempts_correct,
          summary.num_first_attempts,
          summary.num_correct,
          summary.num_attempts
        }
      }
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc "Classifies a naive score using the legacy inclusive 0.4 and 0.8 boundaries."
  def proficiency_range(_score, attempts) when attempts < @minimum_attempts,
    do: "Not enough data"

  def proficiency_range(nil, _attempts), do: "Not enough data"
  def proficiency_range(score, _attempts) when score <= 0.4, do: "Low"
  def proficiency_range(score, _attempts) when score <= 0.8, do: "Medium"
  def proficiency_range(_score, _attempts), do: "High"

  defp estimate(section_id, user_id, objective_id, nil) do
    new_estimate!(section_id, user_id, objective_id, nil, :not_enough_information, 0)
  end

  defp estimate(section_id, user_id, objective_id, {correct, first_attempts}) do
    score =
      case first_attempts do
        0 -> nil
        count -> (correct + 0.2 * (count - correct)) / count
      end

    label = label(score, first_attempts)
    visible_score = if label == :not_enough_information, do: nil, else: score

    new_estimate!(section_id, user_id, objective_id, visible_score, label, first_attempts)
  end

  defp scope_estimate(section_id, user_id, values) do
    {correct, attempts} =
      Enum.reduce(values, {0, 0}, fn {correct, attempts}, {total_correct, total_attempts} ->
        {total_correct + correct, total_attempts + attempts}
      end)

    score = if attempts == 0, do: nil, else: (correct + 0.2 * (attempts - correct)) / attempts
    label = label(score, attempts)

    new_estimate!(
      section_id,
      user_id,
      nil,
      if(label == :not_enough_information, do: nil, else: score),
      label,
      attempts
    )
  end

  defp aggregate_estimates(section, keys, opts, estimate_fun) do
    with {:ok, user_ids} <- user_ids_from(opts),
         {:ok, estimates} <- estimate_fun.(section, user_ids, keys, opts) do
      {:ok, Map.new(estimates, fn {key, by_user} -> {key, aggregate(by_user)} end)}
    end
  end

  defp aggregate(by_user) do
    estimates = Map.values(by_user)
    defined = Enum.filter(estimates, &is_number(&1.score))

    score =
      if defined == [], do: nil, else: Enum.sum(Enum.map(defined, & &1.score)) / length(defined)

    {:ok, aggregate} =
      Aggregate.new(%{
        numeric_score: score,
        distribution: Enum.frequencies_by(estimates, & &1.label),
        contributing_count: length(defined),
        eligible_count: length(defined),
        total_count: length(estimates),
        coverage: %{defined: length(defined), total: length(estimates)}
      })

    aggregate
  end

  defp user_ids_from(opts) do
    case Keyword.fetch(opts, :user_ids) do
      {:ok, user_ids} when is_list(user_ids) -> {:ok, normalize_ids(user_ids)}
      _ -> {:error, {:invalid_option, :user_ids}}
    end
  end

  defp new_estimate!(section_id, user_id, objective_id, score, label, attempts) do
    {:ok, estimate} =
      Estimate.new(%{
        section_id: section_id,
        user_id: user_id,
        learning_objective_id: objective_id,
        score: score,
        label: label,
        confidence: nil,
        attempt_count: attempts,
        unique_activity_part_count: 0,
        learning_model_version: :naive
      })

    estimate
  end

  defp label(_score, attempts) when attempts < @minimum_attempts, do: :not_enough_information
  defp label(nil, _attempts), do: :not_enough_information
  defp label(score, _attempts) when score <= 0.4, do: :low
  defp label(score, _attempts) when score <= 0.8, do: :medium
  defp label(_score, _attempts), do: :high

  defp label_string(:low), do: "Low"
  defp label_string(:medium), do: "Medium"
  defp label_string(:high), do: "High"
  defp label_string(_label), do: "Not enough data"

  defp normalize_ids(ids), do: ids |> Enum.filter(&is_integer/1) |> Enum.uniq()
end
