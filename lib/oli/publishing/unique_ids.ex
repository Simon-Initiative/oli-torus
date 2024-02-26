defmodule Oli.Publishing.UniqueIds do

  alias Oli.Resources.{Revision, ResourceType}
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo
  alias Oli.Resources.PageContent.TraversalContext
  import Ecto.Query
  require Logger

  @doc """
  Adds unique ids to the content of all page and activity revisions in a publication,
  via creation of a new, publication tracked revisions.
  """
  def add_unique_ids(%Publication{ids_added: true}), do: {:ok, 0}
  def add_unique_ids(%Publication{id: publication_id} = publication) do

    # Stream the activity and page revisions, and uniqueify the content
    # for each, then chunk into groups of 50 for bulk insertion of new revisions,
    # returning and collection the mappings of the old revision ids to the new ones,
    # allowing a bulk update of the published_resources at the end.

    Repo.transaction(fn ->

      result = stream_revisions(publication_id)
      |> Stream.map(&uniqueify/1)
      |> Stream.chunk_every(50)
      |> Stream.map(&add_revisions/1)
      |> Enum.to_list()
      |> List.flatten()
      |> update_published_resources(publication_id)

      case result do
        {:ok, num_rows} ->
          mark_publication_as_done(publication)
          num_rows
        e -> Repo.rollback(e)
      end
    end)

  end

  # Stream the page and activity revisions for a specific publication
  defp stream_revisions(publication_id) do

    page_type_id = ResourceType.get_id_by_type("page")
    activity_type_id = ResourceType.get_id_by_type("activity")

    from(rev in Revision,
      join: pr in Oli.Publishing.PublishedResource,
      on: pr.revision_id == rev.id,
      where: pr.publication_id == ^publication_id and
        (rev.resource_type_id == ^page_type_id or rev.resource_type_id == ^activity_type_id)
    )
    |> Repo.stream()
  end

  defp mark_publication_as_done(publication) do
    Publication.changeset(publication, %{ids_added: true})
    |> Repo.update()
  end

  # Given a revision, map over its content, adding ids to all necessary
  # pieces of content.
  # Returns a revision with the modified content in place
  def uniqueify(%Revision{id: id, content: content, resource_type_id: resource_type_id} = revision) do
    %{revision | content: uniqueify(content, resource_type_id, id)}
  end

  def uniqueify(content, resource_type_id, revision_id) do

    # The content manipulation functions are all wrapped in a try
    # to ensure that if any of them fail due to malformed, unexpected
    # data, the process doesn't crash and the content is left as is.
    try do
      if resource_type_id == ResourceType.get_id_by_type("page") do
        {content, _} = uniqueify_content(content)

        content
      else
        {content, _} = do_for_stem({content, MapSet.new()})
        |> do_for_content_collection("choices")
        |> do_for_parts()

        content
      end
    rescue
      _ ->
        Logger.warning("Error uniqueifying content for revision [#{revision_id}]")
        content
    end
  end

  def traversal_context() do
    %Oli.Resources.PageContent.TraversalContext{stop_at_types: ["p"], ignore_types: ["input_ref"]}
  end

  defp uniqueify_content(content, seen_ids \\ MapSet.new()) do
    map_reduce(content, seen_ids, fn e, seen_ids, _tr_context ->

      case Map.get(e, "id") do
        nil ->
          id = Oli.Utils.Slug.random_string(15)
          {Map.put(e, "id", id), MapSet.put(seen_ids, id)}

        id ->
          if MapSet.member?(seen_ids, id) do
            new_id = Oli.Utils.Slug.random_string(15)
            {Map.put(e, "id", new_id), MapSet.put(seen_ids, new_id)}
          else
            {e, MapSet.put(seen_ids, id)}
          end
      end
    end, traversal_context())
  end

  defp do_for_stem({content, seen_ids}) do
    case Map.get(content, "stem") do
      nil -> {content, seen_ids}
      stem -> case Map.get(stem, "content") do
        nil -> {content, seen_ids}
        stem_content ->
          {mapped_content, seen_ids} = uniqueify_content(stem_content, seen_ids)
          {Map.put(content, "stem", Map.put(stem, "content", mapped_content)), seen_ids}
      end
    end
  end

  defp do_for_content_collection({content, seen_ids}, key) do
    case Map.get(content, key) do
      nil -> {content, seen_ids}
      values ->
        {mapped_values, seen_ids} = Enum.reduce(values, {[], seen_ids}, fn value, {all, seen_ids} ->
          case Map.get(value, "content") do
            nil -> {all ++ [value], seen_ids}
            value_content ->
              {mapped_value, seen_ids} = uniqueify_content(value_content, seen_ids)
              {all ++ [Map.put(value, "content", mapped_value)], seen_ids}
          end
        end)
        {Map.put(content, key, mapped_values), seen_ids}
    end
  end

  defp do_for_parts({content, seen_ids}) do
    case Map.get(content, "authoring") do
      nil -> {content, seen_ids}
      authoring -> case Map.get(authoring, "parts") do
        nil -> {content, seen_ids}
        parts ->
          {mapped_parts, seen_ids} = Enum.reduce(parts, {[], seen_ids}, fn part, {all, seen_ids} ->
            {mapped_part, seen_ids} = do_for_part({part, seen_ids})
            {all ++ [mapped_part], seen_ids}
          end)
          {Map.put(content, "authoring", Map.put(authoring, "parts", mapped_parts)), seen_ids}
      end
    end
  end

  defp do_for_responses({content, seen_ids}) do
    case Map.get(content, "responses") do
      nil -> {content, seen_ids}
      responses ->
        {mapped_responses, seen_ids} = Enum.reduce(responses, {[], seen_ids}, fn r, {all, seen_ids} ->
          case Map.get(r, "feedback") do
            nil -> {all ++ [r], seen_ids}
            feedback ->
              case Map.get(feedback, "content") do
                nil -> {all ++ [r], seen_ids}
                feedback_content ->
                  {mapped_feedback, seen_ids} = uniqueify_content(feedback_content, seen_ids)
                  updated_feedback = Map.put(feedback, "content", mapped_feedback)
                  {all ++ [Map.put(r, "feedback", updated_feedback)], seen_ids}
              end
          end
        end)
        {Map.put(content, "responses", mapped_responses), seen_ids}
    end
  end

  defp do_for_explanation({content, seen_ids}) do
    case Map.get(content, "explanation") do
      nil -> {content, seen_ids}
      explanation -> case Map.get(explanation, "content") do
        nil -> {content, seen_ids}
        explanation_content ->
          {mapped_explanation, seen_ids} = uniqueify_content(explanation_content, seen_ids)
          updated_explanation = Map.put(explanation, "content", mapped_explanation)
          {Map.put(content, "explanation", updated_explanation), seen_ids}
      end
    end
  end

  defp do_for_part(content_seen_ids) do
    do_for_content_collection(content_seen_ids, "hints")
    |> do_for_explanation()
    |> do_for_responses()
  end

  # Take a list of revisions and bulk insert them, returning a list of mappings
  # of the old revision ids to the new ones
  defp add_revisions(revisions) do

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs = Enum.map(revisions, fn r ->
      # Wire the new revision up to its previous and drop all the
      # keys that ecto adds in leaving in in a form that we can use in an insert_all
      Map.put(r, :previous_revision_id, r.id)
      |> Map.put(:inserted_at, now)
      |> Map.put(:updated_at, now)
      |> Map.drop([
        :__struct__,
        :__meta__,
        :resource,
        :author,
        :revision,
        :resource_type,
        :id,
        :previous_revision,
        :scoring_strategy,
        :activity_type,
        :primary_resource,
        :warnings,
        :total_count,
        :page_type,
        :parent_slug,
        :total_attempts,
        :avg_score,
      ])
    end)

    {_, mappings} = Repo.insert_all(Revision, attrs, returning: [:id, :previous_revision_id])

    mappings

  end

  # Bulk update the published_resources with the new revision ids
  defp update_published_resources(mappings, publication_id) do

    {values, params, _} =
      Enum.reduce(mappings, {[], [], 2},
        fn %{id: id, previous_revision_id: previous_revision_id}, {values, params, i} ->
        {
          values ++
            [
              "($#{i}::bigint, $#{i + 1}::bigint)"
            ],
          params ++
            [
              previous_revision_id,
              id
            ],
          i + 2
        }
      end)

    values = Enum.join(values, ",")

    sql = """
      UPDATE published_resources
      SET
        revision_id = batch_values.revision_id,
        updated_at = NOW()
      FROM (
          VALUES #{values}
      ) AS batch_values (previous_revision_id, revision_id)
      WHERE published_resources.revision_id = batch_values.previous_revision_id
        and published_resources.publication_id = $1
    """

    case Ecto.Adapters.SQL.query(Repo, sql, [publication_id | params]) do
      {:ok, %{num_rows: num_rows}} -> {:ok, num_rows}
      e -> e
    end

  end

  # An unfortunate, but necessary, duplication of the map_reduce function
  # from the PageContent module. We needed to add "stop_at_types" and "ignore_types"
  # to the traversal context, and it was safer to just copy the function and add
  # this support here, as opposed to risking breaking the existing functionality
  def map_reduce(content, acc, map_fn, tr_context \\ %TraversalContext{})

  def map_reduce(%{"model" => model} = content, acc, map_fn, tr_context) do
    {items, acc} =
      Enum.reduce(model, {[], acc}, fn item, {items, acc} ->
        {item, acc} = map_reduce(item, acc, map_fn, %TraversalContext{tr_context | level: 1})

        {items ++ [item], acc}
      end)

    {Map.put(content, "model", items), acc}
  end

  def map_reduce(%{"type" => "content", "children" => _children} = content, acc, map_fn, tr_context) do
    item_with_children(content, acc, map_fn, tr_context)
  end

  def map_reduce(%{"type" => "content"} = content, acc, map_fn, tr_context) do
    map_fn.(content, acc, tr_context)
  end

  def map_reduce(%{"children" => _children} = item, acc, map_fn, tr_context) do
    item_with_children(item, acc, map_fn, tr_context)
  end

  def map_reduce(item, acc, map_fn, tr_context) when is_list(item) do
    Enum.reduce(item, {[], acc}, fn item, {items, acc} ->

      type = Map.get(item, "type", "")

      cond do
        type in tr_context.ignore_types ->
          {items ++ [item], acc}

        type in tr_context.stop_at_types ->
          {item, acc} = map_fn.(item, acc, tr_context)
          {items ++ [item], acc}
        true ->
          {item, acc} =
            map_reduce(item, acc, map_fn, %TraversalContext{
              tr_context
              | level: tr_context.level + 1
            })
          {items ++ [item], acc}
      end

    end)
  end

  def map_reduce(item, acc, map_fn, tr_context) do
    map_fn.(item, acc, tr_context)
  end

  defp item_with_children(%{"children" => children} = item, acc, map_fn, tr_context) do

    type = Map.get(item, "type", "")

    cond do
      type in tr_context.ignore_types ->
        {item, acc}
      type in tr_context.stop_at_types ->
        map_fn.(item, acc, tr_context)
      true ->
        {children, acc} =
          Enum.reduce(children, {[], acc}, fn item, {items, acc} ->
            {item, acc} =
              map_reduce(item, acc, map_fn, %TraversalContext{
                tr_context
                | level: tr_context.level + 1
              })

            {items ++ [item], acc}
          end)

        Map.put(item, "children", children)
        |> map_fn.(acc, tr_context)
    end
  end


end
