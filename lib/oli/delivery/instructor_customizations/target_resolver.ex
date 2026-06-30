defmodule Oli.Delivery.InstructorCustomizations.TargetResolver do
  @moduledoc false

  alias Oli.Activities.Realizer.Logic
  alias Oli.Activities.Realizer.Query
  alias Oli.Activities.Realizer.Query.Builder
  alias Oli.Activities.Realizer.Query.Paging
  alias Oli.Activities.Realizer.Query.Result
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Repo
  alias Oli.Resources.Revision
  alias Oli.Resources.PageContent
  alias Oli.Resources.ResourceType

  @count_query_paging %Paging{offset: 0, limit: 1}
  @sample_query_paging %Paging{offset: 0, limit: 1}

  # Section/page targets

  @doc """
  Resolves a section struct or id into a current section record.
  """
  @spec resolve_section(%Section{} | integer()) :: {:ok, %Section{}} | {:error, term()}
  def resolve_section(%Section{id: id}), do: resolve_section(id)

  def resolve_section(id) when is_integer(id) do
    case Sections.get_section_by(id: id) do
      nil -> {:error, {:not_found, :section}}
      section -> {:ok, section}
    end
  end

  @doc """
  Resolves a section page resource to its current non-adaptive page revision.
  """
  @spec resolve_page(%Section{}, integer()) :: {:ok, %Revision{}} | {:error, term()}
  def resolve_page(%Section{} = section, page_resource_id) when is_integer(page_resource_id) do
    case Sections.get_section_revision_for_resource(section.slug, page_resource_id) do
      nil ->
        {:error, {:not_found, :page}}

      revision ->
        case {ResourceType.is_page(revision), ResourceType.is_adaptive_page(revision)} do
          {true, false} -> {:ok, revision}
          {true, true} -> {:error, {:invalid_page_type, :adaptive}}
          _ -> {:error, {:not_found, :page}}
        end
    end
  end

  @doc """
  Resolves the preview-route target for one bank selection on one page revision slug.
  """
  @spec resolve_bank_selection_preview_target(%Section{}, String.t(), String.t()) ::
          {:ok, %Revision{}, map()} | {:error, term()}
  def resolve_bank_selection_preview_target(
        %Section{} = section,
        revision_slug,
        selection_id
      )
      when is_binary(revision_slug) and is_binary(selection_id) do
    with revision when not is_nil(revision) <-
           DeliveryResolver.from_revision_slug(section.slug, revision_slug),
         {:ok, page_revision} <- ensure_basic_page_revision(revision),
         {:ok, selection} <- resolve_selection(page_revision, selection_id) do
      {:ok, page_revision, selection}
    else
      nil -> {:error, {:not_found, :page}}
      error -> error
    end
  end

  # Page content targets

  @doc """
  Validates that an embedded activity reference exists in the given page revision.
  """
  @spec validate_embedded_activity_reference(%Revision{}, integer()) :: :ok | {:error, term()}
  def validate_embedded_activity_reference(page_revision, activity_resource_id)
      when is_integer(activity_resource_id) do
    activity =
      PageContent.flat_filter(page_revision.content, fn
        %{"type" => "activity-reference", "activity_id" => ^activity_resource_id} -> true
        _ -> false
      end)

    case activity do
      [] -> {:error, {:not_found, :activity}}
      _ -> :ok
    end
  end

  @doc """
  Resolves a bank selection element from the given page revision content.
  """
  @spec resolve_selection(%Revision{}, String.t()) :: {:ok, map()} | {:error, term()}
  def resolve_selection(page_revision, selection_id) when is_binary(selection_id) do
    selections =
      PageContent.flat_filter(page_revision.content, fn
        %{"type" => "selection", "id" => ^selection_id} -> true
        _ -> false
      end)

    case selections do
      [selection | _] -> {:ok, selection}
      [] -> {:error, {:not_found, :selection}}
    end
  end

  defp ensure_basic_page_revision(revision) do
    case {ResourceType.is_page(revision), ResourceType.is_adaptive_page(revision)} do
      {true, false} -> {:ok, revision}
      {true, true} -> {:error, {:invalid_page_type, :adaptive}}
      _ -> {:error, {:not_found, :page}}
    end
  end

  # Bank candidate queries

  @doc """
  Lists current bank candidates matching the selection logic.
  """
  @spec list_candidates(%Section{}, %Revision{}, map(), Paging.t()) ::
          {:ok, map()} | {:error, term()}
  def list_candidates(%Section{} = section, page_revision, selection, %Paging{} = paging) do
    execute_candidate_query(section, page_revision, selection, [], paging)
  end

  @doc """
  Lists bank candidates after excluding resource ids.
  """
  @spec list_active_candidates(%Section{}, %Revision{}, map(), MapSet.t(integer()), Paging.t()) ::
          {:ok, map()} | {:error, term()}
  def list_active_candidates(
        %Section{} = section,
        page_revision,
        selection,
        excluded_ids,
        %Paging{} = paging
      ) do
    execute_candidate_query(
      section,
      page_revision,
      selection,
      MapSet.to_list(excluded_ids),
      paging
    )
  end

  @doc """
  Lists bank candidates for all page selections in one database round trip.
  """
  @spec list_active_candidates_by_selection_id(
          %Section{},
          %Revision{},
          [map()],
          %{optional(String.t()) => MapSet.t(integer())},
          %Paging{}
        ) :: {:ok, %{String.t() => %Result{}}} | {:error, term()}
  def list_active_candidates_by_selection_id(
        %Section{} = section,
        %Revision{} = page_revision,
        selections,
        excluded_ids_by_selection_id,
        %Paging{} = paging
      )
      when is_list(selections) and is_map(excluded_ids_by_selection_id) do
    publication_id =
      Publishing.get_publication_id_for_resource(section.slug, page_revision.resource_id)

    with {:ok, query} <-
           build_candidate_queries_by_selection_id(
             section,
             selections,
             excluded_ids_by_selection_id,
             publication_id,
             paging
           ),
         {:ok, %Postgrex.Result{} = result} <- execute_candidate_queries(query) do
      {:ok, candidate_results_by_selection_id(result, selections)}
    end
  end

  @doc """
  Counts candidates matching the selection logic after excluding resource ids.
  """
  @spec count_active_candidates(%Section{}, %Revision{}, map(), MapSet.t(integer())) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def count_active_candidates(%Section{} = section, page_revision, selection, excluded_ids) do
    with {:ok, result} <-
           execute_candidate_query(
             section,
             page_revision,
             selection,
             MapSet.to_list(excluded_ids),
             @count_query_paging
           ) do
      {:ok, result.totalCount}
    end
  end

  @doc """
  Lists all candidate activity type ids for a resolved selection target.
  """
  @spec list_candidate_activity_type_ids(%Section{}, %Revision{}, map(), non_neg_integer()) ::
          {:ok, [integer()]} | {:error, term()}
  def list_candidate_activity_type_ids(
        %Section{} = section,
        page_revision,
        selection,
        total_count
      )
      when is_integer(total_count) and total_count >= 0 do
    with {:ok, result} <-
           execute_candidate_query(
             section,
             page_revision,
             selection,
             [],
             %Paging{offset: 0, limit: max(total_count, 1)}
           ) do
      {:ok,
       result.rows
       |> Enum.map(& &1.activity_type_id)
       |> Enum.uniq()}
    end
  end

  @doc """
  Returns one random active candidate matching the selection logic.
  """
  def sample_candidate(%Section{} = section, page_revision, selection, excluded_ids) do
    with {:ok, result} <-
           execute_candidate_query(
             section,
             page_revision,
             selection,
             MapSet.to_list(excluded_ids),
             @sample_query_paging,
             nil,
             :random
           ) do
      {:ok, List.first(result.rows)}
    end
  end

  @doc """
  Returns whether a resource id is a current candidate for the selection.
  """
  @spec candidate_matches?(%Section{}, %Revision{}, map(), integer()) ::
          {:ok, boolean()} | {:error, term()}
  def candidate_matches?(%Section{} = section, page_revision, selection, candidate_resource_id)
      when is_integer(candidate_resource_id) do
    # A returned revision proves the candidate belongs to the published bank and
    # satisfies the selection logic without loading the full matching bank.
    with {:ok, result} <-
           execute_candidate_query(
             section,
             page_revision,
             selection,
             [],
             @count_query_paging,
             [candidate_resource_id]
           ) do
      {:ok, result.rows != []}
    end
  end

  defp execute_candidate_query(
         section,
         page_revision,
         selection,
         blacklisted_ids,
         paging,
         activity_resource_ids \\ nil,
         query_type \\ :paged
       ) do
    with {:ok, %Logic{} = logic} <- parse_logic(selection),
         publication_id <-
           Publishing.get_publication_id_for_resource(section.slug, page_revision.resource_id),
         {:ok, result} <-
           execute_query(
             query_type,
             logic,
             %Source{
               publication_id: publication_id,
               section_slug: section.slug,
               blacklisted_activity_ids: blacklisted_ids,
               activity_resource_ids: activity_resource_ids
             },
             paging
           ) do
      {:ok, result}
    end
  end

  defp execute_query(:paged, logic, source, paging), do: Query.execute(logic, source, paging)

  defp execute_query(:random, logic, source, paging),
    do: Query.execute_random(logic, source, paging)

  defp build_candidate_queries_by_selection_id(
         section,
         selections,
         excluded_ids_by_selection_id,
         publication_id,
         paging
       ) do
    case Enum.reduce_while(selections, {:ok, [], [], 0}, fn selection,
                                                            {:ok, branches, param_groups,
                                                             param_count} ->
           selection_id = selection["id"]

           with {:ok, %Logic{} = logic} <- parse_logic(selection) do
             excluded_ids =
               excluded_ids_by_selection_id
               |> Map.get(selection_id, MapSet.new())
               |> MapSet.to_list()

             {sql, sql_params} =
               Builder.build(
                 logic,
                 %Source{
                   publication_id: publication_id,
                   section_slug: section.slug,
                   blacklisted_activity_ids: excluded_ids
                 },
                 paging,
                 :paged
               )

             # Each selection keeps its own realizer SQL; wrap each branch with a selection id
             # and shift placeholders so all branches can run as one UNION query.
             selection_id_param = param_count + 1
             shifted_sql = shift_sql_parameters(sql, selection_id_param)

             branch =
               "SELECT $#{selection_id_param}::text AS selection_id, candidate_rows.* FROM (#{shifted_sql}) AS candidate_rows"

             {:cont,
              {:ok, [branch | branches], [[selection_id | sql_params] | param_groups],
               param_count + 1 + length(sql_params)}}
           else
             error -> {:halt, error}
           end
         end) do
      {:ok, [], _param_groups, _param_count} ->
        {:ok, {nil, []}}

      {:ok, branches, param_groups, _param_count} ->
        params =
          param_groups
          |> Enum.reverse()
          |> List.flatten()

        {:ok, {branches |> Enum.reverse() |> Enum.join(" UNION ALL "), params}}

      error ->
        error
    end
  end

  defp shift_sql_parameters(sql, offset) do
    Regex.replace(~r/\$(\d+)/, sql, fn _match, number ->
      "$#{String.to_integer(number) + offset}"
    end)
  end

  defp execute_candidate_queries({nil, _params}) do
    {:ok, %Postgrex.Result{columns: [], rows: [], num_rows: 0}}
  end

  defp execute_candidate_queries({sql, params}), do: Ecto.Adapters.SQL.query(Repo, sql, params)

  defp candidate_results_by_selection_id(
         %Postgrex.Result{rows: rows, columns: columns},
         selections
       ) do
    selection_index = Enum.find_index(columns, &(&1 == "selection_id"))
    count_index = Enum.find_index(columns, &(&1 == "full_count"))
    revision_column_indexes = revision_column_indexes(columns)

    empty_results =
      Map.new(selections, fn selection ->
        {selection["id"], %Result{rows: [], rowCount: 0, totalCount: 0}}
      end)

    rows
    |> Enum.map(fn row ->
      selection_id = Enum.at(row, selection_index)
      revision = candidate_revision_from_row(row, revision_column_indexes)
      full_count = if count_index, do: Enum.at(row, count_index), else: 0

      {selection_id, revision, full_count}
    end)
    |> Enum.group_by(fn {selection_id, _revision, _full_count} -> selection_id end)
    |> Map.new(fn {selection_id, candidate_rows} ->
      rows = Enum.map(candidate_rows, fn {_selection_id, revision, _full_count} -> revision end)
      total_count = candidate_rows |> List.first() |> elem(2)

      {selection_id, %Result{rows: rows, rowCount: length(rows), totalCount: total_count}}
    end)
    |> then(&Map.merge(empty_results, &1))
  end

  defp revision_column_indexes(columns) do
    columns
    |> Enum.with_index()
    |> Enum.reject(fn {column, _index} -> column in ["selection_id", "full_count"] end)
    |> Enum.map(fn {column, index} -> {index, String.to_existing_atom(column)} end)
  end

  defp candidate_revision_from_row(row, revision_column_indexes) do
    revision_column_indexes
    |> Enum.map(fn {index, column} -> {column, Enum.at(row, index)} end)
    |> then(&Repo.load(Revision, &1))
  end

  defp parse_logic(%{"logic" => logic}) do
    case Logic.parse(logic) do
      {:ok, %Logic{} = parsed} -> {:ok, parsed}
      {:error, "no values provided for expression"} -> {:ok, %Logic{conditions: nil}}
      error -> error
    end
  end
end
