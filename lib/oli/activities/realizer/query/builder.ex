defmodule Oli.Activities.Realizer.Query.Builder do
  @moduledoc """
  Given logic constraints, a source and view and paging options, this
  module assembles the raw SQL that when executed will select activities
  from a course project activity bank.
  """

  alias Oli.Resources.ResourceType
  alias Oli.Activities.Realizer.Logic
  alias Oli.Activities.Realizer.Logic.Expression
  alias Oli.Activities.Realizer.Logic.Clause
  alias Oli.Activities.Realizer.Query.Paging
  alias Oli.Activities.Realizer.Query.Source

  def build(%Logic{} = logic, %Source{} = source, %Paging{} = paging, view_type) do
    context = %{params: [], exact_objectives: false}

    %{params: params, sql: sql} =
      select(context, view_type)
      |> from()
      |> where(logic)
      |> source(source)
      |> limit_offset(paging, view_type)
      |> with_flattened_objectives()
      |> assemble()

    {sql, params}
  end

  defp assemble(context) do
    Map.put(
      context,
      :sql,
      normalize_whitespace("""
      #{context.with_flattened_objectives}
      #{context.select}
      #{context.from}
      #{context.with_flattened_objectives_join}
      WHERE #{context.source} AND (#{context.logic})
      #{context.limit_offset}
      """)
    )
  end

  defp limit_offset(context, %Paging{limit: limit, offset: offset}, view_type) do
    Map.put(
      context,
      :limit_offset,
      case view_type do
        :random -> "ORDER BY RANDOM() LIMIT #{limit}"
        :paged -> "ORDER BY revisions.resource_id LIMIT #{limit} OFFSET #{offset}"
      end
    )
  end

  defp select(context, view_type) do
    Map.put(
      context,
      :select,
      case view_type do
        :random -> "SELECT revisions.* "
        :paged -> "SELECT revisions.*, count(*) OVER() as full_count "
      end
    )
  end

  defp source(context, %Source{
         publication_id: publication_id,
         blacklisted_activity_ids: blacklisted_activity_ids
       }) do
    activity_type_id = ResourceType.id_for_activity()

    blacklisted =
      case blacklisted_activity_ids do
        [] -> ""
        items -> "(NOT (revisions.resource_id IN (#{Enum.join(items, ",")}))) AND "
      end

    Map.put(
      context,
      :source,
      """
      #{blacklisted}(revisions.resource_type_id = #{activity_type_id})
      AND (published_resources.publication_id = #{publication_id})
      AND (revisions.scope = 'banked')
      AND (revisions.deleted = false)
      """
    )
  end

  defp from(context) do
    Map.put(
      context,
      :from,
      "FROM published_resources LEFT JOIN revisions ON revisions.id = published_resources.revision_id"
    )
  end

  defp where(context, %Logic{conditions: conditions}) do
    case conditions do
      nil ->
        Map.put(context, :logic, "1 = 1")

      _ ->
        {fragments, context} = build_where(conditions, context)
        Map.put(context, :logic, IO.iodata_to_binary(fragments))
    end
  end

  defp with_flattened_objectives(context) do
    Map.put(
      context,
      :with_flattened_objectives,
      if context.exact_objectives do
        """
        WITH flattened_objectives AS (
          SELECT
              revisions.id,
              ARRAY_AGG(DISTINCT elem ORDER BY elem) AS objectives_array
          FROM
              revisions
          JOIN
              LATERAL (
                  SELECT jsonb_array_elements_text(value) AS elem
                  FROM jsonb_each(revisions.objectives)
              ) AS elems ON true
          GROUP BY
              revisions.id
        )
        """
      else
        ""
      end
    )
    |> Map.put(:with_flattened_objectives_join,
      if context.exact_objectives do
        "JOIN flattened_objectives ON flattened_objectives.id = revisions.id"
      else ""
    end)
  end

  def normalize_whitespace(sql) do
    String.replace(sql, ~r/\s+/, " ")
    |> String.trim()
  end

  defp build_where(%Clause{operator: operator, children: children}, peripherals) do
    {fragments, peripherals} =
      Enum.reduce(children, {[], peripherals}, fn e, {f, p} ->
        {inner_fragments, inner_params} = build_where(e, p)
        {f ++ inner_fragments, inner_params}
      end)

    joiner =
      case operator do
        :any -> " OR "
        :all -> " AND "
      end

    {[["(", Enum.intersperse(fragments, joiner), ")"]], peripherals}
  end

  defp build_where(%Expression{fact: :tags, operator: operator, value: value}, peripherals) do
    fragment =
      case operator do
        :contains -> ["tags @> ARRAY[" <> Enum.join(value, ",") <> "]"]
        :does_not_contain -> ["(NOT (tags @> ARRAY[" <> Enum.join(value, ",") <> "]))"]
        :equals -> ["tags = ARRAY[" <> Enum.join(value, ",") <> "]"]
        :does_not_equal -> ["(NOT tags = ARRAY[" <> Enum.join(value, ",") <> "])"]
      end

    {fragment, peripherals}
  end

  defp build_where(%Expression{fact: :objectives, operator: operator, value: value}, peripherals) do
    fragment =
      case operator do
        :contains ->
          [build_objectives_disjunction(value)]

        :does_not_contain ->
          ["(NOT (" <> build_objectives_disjunction(value) <> "))"]

        :equals ->
          ["flattened_objectives.objectives_array = ARRAY[" <> Enum.join(value, ",") <> "]::text[]"]

        :does_not_equal ->
          [
            "NOT (flattened_objectives.objectives_array = ARRAY[" <> Enum.join(value, ",") <> "]::text[])"
          ]
      end

    peripherals =
      if operator == :equals or operator == :does_not_equal do
        Map.put(peripherals, :exact_objectives, true)
      else
        peripherals
      end

    {fragment, peripherals}
  end

  defp build_where(%Expression{fact: :text, operator: _, value: value}, peripherals) do
    peripherals = Map.put(peripherals, :params, peripherals.params ++ [value])

    {["(to_tsvector(content) @@ to_tsquery($1))"], peripherals}
  end

  defp build_where(%Expression{fact: :type, operator: operator, value: value}, peripherals) do
    fragment =
      case operator do
        :contains -> ["activity_type_id in (" <> Enum.join(value, ",") <> ")"]
        :does_not_contain -> ["(NOT (activity_type_id in (" <> Enum.join(value, ",") <> ")))"]
        :equals -> ["activity_type_id = #{value}"]
        :does_not_equal -> ["activity_type_id != #{value}"]
      end

    {fragment, peripherals}
  end

  defp build_objectives_disjunction(objective_ids) do
    id_filter =
      Enum.map(objective_ids, fn id -> "@ == #{id}" end)
      |> Enum.join(" || ")

    "jsonb_path_exists(objectives, '$.** ? (#{id_filter})')"
  end

end
