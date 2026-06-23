defmodule Oli.Delivery.InstructorCustomizations.TargetResolver do
  @moduledoc false

  alias Oli.Activities.Realizer.Logic
  alias Oli.Activities.Realizer.Query
  alias Oli.Activities.Realizer.Query.Paging
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing
  alias Oli.Resources.PageContent
  alias Oli.Resources.ResourceType

  @count_query_paging %Paging{offset: 0, limit: 1}

  # Section/page targets

  @doc """
  Resolves a section struct or id into a current section record.
  """
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

  # Page content targets

  @doc """
  Validates that an embedded activity reference exists in the given page revision.
  """
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

  # Bank candidate queries

  @doc """
  Lists current bank candidates matching the selection logic.
  """
  def list_candidates(%Section{} = section, page_revision, selection, %Paging{} = paging) do
    execute_candidate_query(section, page_revision, selection, [], paging)
  end

  @doc """
  Counts candidates matching the selection logic after excluding resource ids.
  """
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
  Returns whether a resource id is a current candidate for the selection.
  """
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
         activity_resource_ids \\ nil
       ) do
    with {:ok, %Logic{} = logic} <- parse_logic(selection),
         publication_id <-
           Publishing.get_publication_id_for_resource(section.slug, page_revision.resource_id),
         {:ok, result} <-
           Query.execute(
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

  defp parse_logic(%{"logic" => logic}) do
    case Logic.parse(logic) do
      {:ok, %Logic{} = parsed} -> {:ok, parsed}
      {:error, "no values provided for expression"} -> {:ok, %Logic{conditions: nil}}
      error -> error
    end
  end
end
