defmodule Oli.Activities.Realizer.QueryBuilder do
  alias Oli.Activities.Realizer.Conditions
  alias Oli.Activities.Realizer.Conditions.Expression
  alias Oli.Activities.Realizer.Conditions.Clause

  def build(%Conditions{conditions: conditions}, publication_id) do
    {fragments, params} = build_where(conditions, [])
    as_string = IO.iodata_to_binary(fragments)

    select =
      "SELECT revisons.* FROM published_resources LEFT JOIN revisions ON revisions.id = published_resources.revision_id"

    {"#{select} WHERE (published_resources.publication_id = #{publication_id}) AND (#{as_string})",
     params}
  end

  defp build_where(%Clause{operator: operator, children: children}, params) do
    {fragments, params} =
      Enum.reduce(children, {[], params}, fn e, {f, p} ->
        {inner_fragments, inner_params} = build_where(e, p)
        {f ++ inner_fragments, inner_params}
      end)

    joiner =
      case operator do
        :any -> " OR "
        :all -> " AND "
      end

    {[["(", Enum.intersperse(fragments, joiner), ")"]], params}
  end

  defp build_where(%Expression{fact: :tags, operator: operator, value: value}, params) do
    fragment =
      case operator do
        :contains -> ["tags @> ARRAY[" <> Enum.join(value, ",") <> "]"]
        :does_not_contain -> ["(NOT (tags @> ARRAY[" <> Enum.join(value, ",") <> "]))"]
        :equals -> ["tags = ARRAY[" <> Enum.join(value, ",") <> "]"]
        :does_not_equal -> ["(NOT tags = ARRAY[" <> Enum.join(value, ",") <> "])"]
      end

    {fragment, params}
  end

  defp build_where(%Expression{fact: :objectives, operator: operator, value: value}, params) do
    fragment =
      case operator do
        :contains -> [build_objectives_disjunction(value)]
        :does_not_contain -> ["(NOT (" <> build_objectives_disjunction(value) <> "))"]
        :equals -> [build_objectives_conjunction(value)]
        :does_not_equal -> ["(NOT (" <> build_objectives_conjunction(value) <> "))"]
      end

    {fragment, params}
  end

  defp build_where(%Expression{fact: :text, operator: _, value: value}, params) do
    {["(to_tsvector(content) @@ to_tsquery($1))"], params ++ [value]}
  end

  defp build_where(%Expression{fact: :type, operator: operator, value: value}, params) do
    fragment =
      case operator do
        :contains -> ["activity_type_id in (" <> Enum.join(value, ",") <> ")"]
        :does_not_contain -> ["(NOT (activity_type_id in (" <> Enum.join(value, ",") <> ")))"]
        :equals -> ["activity_type_id = #{value}"]
        :does_not_equal -> ["activity_type_id != #{value}"]
      end

    {fragment, params}
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
