defmodule Oli.Delivery.InstructorCustomizations.TargetResolver do
  @moduledoc """
  Resolves preview customization targets and candidate-query inputs for
  instructor customization flows.

  This module keeps section/page/selection lookup and activity-bank candidate
  queries behind one delivery-owned boundary so callers can share the same
  validation rules without duplicating selection-resolution logic.
  """

  alias Oli.Activities.Realizer.Logic
  alias Oli.Activities.Realizer.Logic.Clause
  alias Oli.Activities.Realizer.Logic.Expression
  alias Oli.Activities.Realizer.Query
  alias Oli.Activities.Realizer.Query.Batch
  alias Oli.Activities.Realizer.Query.Paging
  alias Oli.Activities.Realizer.Query.Result
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.Revision
  alias Oli.Resources.PageContent
  alias Oli.Resources.ResourceType

  @count_query_paging %Paging{offset: 0, limit: 1}
  @sample_query_paging %Paging{offset: 0, limit: 1}
  @candidate_query_chunk_size 10

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
    list_candidates(section, page_revision, selection, paging, %{}, [])
  end

  @doc """
  Lists current bank candidates with additional filter criteria and query scope options.
  """
  @spec list_candidates(%Section{}, %Revision{}, map(), Paging.t(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def list_candidates(
        %Section{} = section,
        page_revision,
        selection,
        %Paging{} = paging,
        filters,
        opts
      )
      when is_map(filters) and is_list(opts) do
    execute_candidate_query(
      section,
      page_revision,
      selection,
      Keyword.get(opts, :blacklisted_ids, []),
      paging,
      Keyword.get(opts, :activity_resource_ids),
      :paged,
      filters
    )
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
      paging,
      nil,
      :paged,
      %{}
    )
  end

  @doc """
  Lists bank candidates for all page selections in bounded database round trips.
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

    selections
    |> Enum.chunk_every(@candidate_query_chunk_size)
    |> Enum.reduce_while({:ok, %{}}, fn chunk, {:ok, acc} ->
      with {:ok, query_specs} <-
             build_candidate_query_specs(
               section,
               chunk,
               excluded_ids_by_selection_id,
               publication_id
             ),
           {:ok, results_by_selection_id} <- Batch.execute(query_specs, paging, :paged) do
        {:cont, {:ok, Map.merge(acc, results_by_selection_id)}}
      else
        error -> {:halt, error}
      end
    end)
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
             @count_query_paging,
             nil,
             :paged,
             %{}
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
             %Paging{offset: 0, limit: max(total_count, 1)},
             nil,
             :paged,
             %{}
           ) do
      {:ok,
       result.rows
       |> Enum.map(& &1.activity_type_id)
       |> Enum.uniq()}
    end
  end

  @doc """
  Lists all candidate rows needed to build filter option sets for a resolved selection target.
  """
  @spec list_candidate_filter_option_rows(%Section{}, %Revision{}, map(), non_neg_integer()) ::
          {:ok, [%Revision{}]} | {:error, term()}
  def list_candidate_filter_option_rows(
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
             %Paging{offset: 0, limit: max(total_count, 1)},
             nil,
             :paged,
             %{}
           ) do
      {:ok, result.rows}
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
             :random,
             %{}
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
             [candidate_resource_id],
             :paged,
             %{}
           ) do
      {:ok, result.rows != []}
    end
  end

  @doc """
  Returns the subset of resource ids that currently match the selection.

  This is the set-based companion to `candidate_matches?/4` for callers that
  need to validate multiple candidate ids at once without issuing one query per
  resource id.
  """
  @spec candidates_match?(%Section{}, %Revision{}, map(), [integer()]) ::
          {:ok, MapSet.t(integer())} | {:error, term()}
  def candidates_match?(
        %Section{} = section,
        page_revision,
        selection,
        candidate_resource_ids
      )
      when is_list(candidate_resource_ids) do
    candidate_resource_ids =
      candidate_resource_ids
      |> Enum.filter(&is_integer/1)
      |> Enum.uniq()

    case candidate_resource_ids do
      [] ->
        {:ok, MapSet.new()}

      candidate_resource_ids ->
        with {:ok, result} <-
               execute_candidate_query(
                 section,
                 page_revision,
                 selection,
                 [],
                 %Paging{offset: 0, limit: length(candidate_resource_ids)},
                 candidate_resource_ids,
                 :paged,
                 %{}
               ) do
          {:ok, MapSet.new(Enum.map(result.rows, & &1.resource_id))}
        end
    end
  end

  defp execute_candidate_query(
         section,
         page_revision,
         selection,
         blacklisted_ids,
         paging,
         activity_resource_ids,
         query_type,
         filters
       ) do
    with {:ok, %Logic{} = logic} <- parse_logic(selection),
         %Logic{} = filtered_logic <- apply_candidate_filters(logic, filters),
         publication_id <-
           Publishing.get_publication_id_for_resource(section.slug, page_revision.resource_id),
         {:ok, result} <-
           execute_query(
             query_type,
             filtered_logic,
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

  defp build_candidate_query_specs(
         section,
         selections,
         excluded_ids_by_selection_id,
         publication_id
       ) do
    Enum.reduce_while(selections, {:ok, []}, fn selection, {:ok, acc} ->
      with {:ok, %Logic{} = logic} <- parse_logic(selection) do
        selection_id = selection["id"]

        excluded_ids =
          excluded_ids_by_selection_id
          |> Map.get(selection_id, MapSet.new())
          |> MapSet.to_list()

        source = %Source{
          publication_id: publication_id,
          section_slug: section.slug,
          blacklisted_activity_ids: excluded_ids
        }

        {:cont, {:ok, [{selection_id, logic, source} | acc]}}
      else
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, query_specs} -> {:ok, Enum.reverse(query_specs)}
      error -> error
    end
  end

  defp parse_logic(%{"logic" => logic}) do
    case Logic.parse(logic) do
      {:ok, %Logic{} = parsed} -> {:ok, parsed}
      {:error, "no values provided for expression"} -> {:ok, %Logic{conditions: nil}}
      error -> error
    end
  end

  defp apply_candidate_filters(%Logic{} = logic, filters) do
    expressions =
      []
      |> maybe_add_text_search_filter(Map.get(filters, :text_search, ""))
      |> maybe_add_objective_filter(Map.get(filters, :objective_ids, []))
      |> maybe_add_activity_type_filter(Map.get(filters, :activity_type_ids, []))

    case {logic.conditions, expressions} do
      {_conditions, []} ->
        logic

      {nil, expressions} ->
        %{logic | conditions: %Clause{operator: :all, children: expressions}}

      {conditions, expressions} ->
        %{logic | conditions: %Clause{operator: :all, children: [conditions | expressions]}}
    end
  end

  defp maybe_add_text_search_filter(expressions, text_search) do
    case text_search_query(text_search) do
      "" ->
        expressions

      query ->
        expressions ++
          [%Expression{fact: :text, operator: :contains, value: query}]
    end
  end

  defp maybe_add_objective_filter(expressions, []), do: expressions

  defp maybe_add_objective_filter(expressions, [objective_id]) do
    expressions ++
      [%Expression{fact: :objectives, operator: :contains, value: [objective_id]}]
  end

  defp maybe_add_objective_filter(expressions, objective_ids) do
    expressions ++
      [
        %Clause{
          operator: :any,
          children:
            Enum.map(objective_ids, fn objective_id ->
              %Expression{fact: :objectives, operator: :contains, value: [objective_id]}
            end)
        }
      ]
  end

  defp maybe_add_activity_type_filter(expressions, []), do: expressions

  defp maybe_add_activity_type_filter(expressions, activity_type_ids) do
    expressions ++
      [%Expression{fact: :type, operator: :contains, value: activity_type_ids}]
  end

  defp text_search_query(text_search) when is_binary(text_search) do
    text_search
    |> String.split(~r/[^\p{L}\p{N}_]+/u, trim: true)
    |> Enum.join(" & ")
  end

  defp text_search_query(_text_search), do: ""
end
