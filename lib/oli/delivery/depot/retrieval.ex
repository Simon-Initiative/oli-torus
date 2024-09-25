defmodule Oli.Delivery.Depot.Retrieval do

  alias Oli.Delivery.Depot.DepotDesc
  alias Oli.Delivery.Depot.MatchSpecTranslator


  @doc """
  Return all records in a specific depot.

  Examples:

  Return all records, all fields
  > Retrieval.all(depot_desc)

  Return all records, but only the id and title fields
  > Retrieval.all(depot_desc, [:id, :title])
  """
  def all(%DepotDesc{} = depot_desc, key_value) do
    :ets.lookup(depot_desc.table, key_value)
  end

  @doc """
  Query the section resources for matching records, applying the specified logical
  conditions and, optionally, returning only the specified fields.

  Examples:

  All graded pages in key 1
  > Retrieval.query(depot_desc, 1, graded: true, resource_type_id: 1)

  All units in key 4
  > Retrieval.query(depot_desc, 4, numbering_level: 1, resource_type_id: 2)

  A list of maps of id and titles of all exploration pages in key 3
  > Retrieval.query(depot_desc, 3, [purpose: :exploration], [:id, :title])

  Assignments due in the next 7 days
  > Retrieval.query(depot_desc, 3, [graded: true, scheduling_type: :due_by, end_date: [:between, DateTime.utc_now(), DateTime.utc_now() + 7]])

  Assignments that either have a time limit or a due date
  > Retrieval.query(depot_desc, 3, [[graded: true, scheduling_type: :due_by], [graded: true, time_limit: [:not_eq, 0]]])
  """
  def query(%DepotDesc{} = depot_desc, key_value, conditions, field_list \\ []) do

    field_pairs = build_field_pairs(depot_desc.schema)
    match_spec = MatchSpecTranslator.translate(field_pairs, key_value, conditions, field_list)

    :ets.select(depot_desc.table, [match_spec])
  end

  defp build_field_pairs(schema) do
    apply(schema, :__schema__, [:fields])
    |> Enum.map(fn field -> {field, apply(schema, :__schema__, [:type, field])} end)
  end

end
