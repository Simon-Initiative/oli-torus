defmodule Oli.Activities.Realizer.QueryBuilder do
  alias Oli.Resources.ResourceType
  alias Oli.Activities.Realizer.Conditions
  alias Oli.Activities.Realizer.Conditions.Expression
  alias Oli.Activities.Realizer.Conditions.Clause
  alias Oli.Activities.Realizer.Paging

  def build_for_paging(
        %Conditions{conditions: conditions},
        publication_id,
        %Paging{} = paging_options
      ) do
    {sql, params} = build(conditions, publication_id, [])

    {"#{sql} #{paging(paging_options)}", params}
  end

  def build_for_selection(
        %Conditions{} = conditions,
        publication_id,
        count,
        blacklisted_activity_ids
      ) do
    {sql, params} = build(conditions, publication_id, blacklisted_activity_ids)

    {"#{sql} #{random_selection(count)}", params}
  end

  def build(%Conditions{conditions: conditions}, publication_id, blacklisted_activity_ids) do
    peripherals = %{params: [], exact_objectives: false}

    {fragments, peripherals} = build_where(conditions, peripherals)
    selection_clauses = IO.iodata_to_binary(fragments)

    select =
      "SELECT revisons.* FROM published_resources LEFT JOIN revisions ON revisions.id = published_resources.revision_id"

    objectives_count_join =
      if peripherals.exact_objectives do
        """
        JOIN LATERAL (select id, sum(jsonb_array_length(value)) as objectives_count
        from revisions, jsonb_each(revisions.objectives) group by id
        ) AS count ON count.id = revisions.id
        """
      else
        ""
      end

    activity_type_id = ResourceType.get_id_by_type("activity")

    blacklisted =
      case blacklisted_activity_ids do
        [] -> ""
        items -> "(NOT (revisions.resource_id IN (#{Enum.join(items, ",")}))) AND "
      end

    published_activities =
      "#{blacklisted}(revisions.resource_type_id = #{activity_type_id}) AND (published_resources.publication_id = #{publication_id})"

    sql =
      normalize_whitespace(
        "#{select} #{objectives_count_join} WHERE #{published_activities} AND (#{selection_clauses})"
      )

    {sql, peripherals.params}
  end

  defp paging(%Paging{limit: limit, offset: offset}) do
    "LIMIT #{limit} OFFSET #{offset}"
  end

  defp random_selection(count) do
    "ORDER BY RANDOM() LIMIT #{count}"
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
          ["(objectives_count = #{length(value)} AND (#{build_objectives_conjunction(value)})"]

        :does_not_equal ->
          [
            "(NOT ((objectives_count = #{length(value)} AND (#{build_objectives_conjunction(value)})))"
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

    "jsonb_path_match(objectives, 'exists($.** ? (#{id_filter}))')'"
  end

  defp build_objectives_conjunction(objective_ids) do
    clauses =
      Enum.map(objective_ids, fn id -> build_objectives_disjunction([id]) end)
      |> Enum.join(" AND ")

    "(#{clauses})"
  end
end
