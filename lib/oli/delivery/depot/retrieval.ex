defmodule Oli.Delivery.Depot.Retrieval do

  alias Oli.Delivery.Depot.Serializer

  def build(section_id, field_values), do: Serializer.serialize(section_id, field_values)

  @doc """
  Query the section resources for matching records

  Examples:

  All graded pages in section 1
  > Retrieval.query(1, graded: true, resource_type_id: 1)

  All units in section 4
  > Retrieval.query(4, numbering_level: 1, resource_type_id: 2)

  A list of maps of id and titles of all exploration pages in section 3
  > Retrieval.query(3, [purpose: :exploration], [:id, :title])
  """
  def all(section_id, field_spec \\ []) do




  end

  @doc """
  Query the section resources for matching records, applying the specified logical
  conditions and, optionally, returning only the specified fields.

  Examples:

  All graded pages in section 1
  > Retrieval.query(1, graded: true, resource_type_id: 1)

  All units in section 4
  > Retrieval.query(4, numbering_level: 1, resource_type_id: 2)

  A list of maps of id and titles of all exploration pages in section 3
  > Retrieval.query(3, [purpose: :exploration], [:id, :title])

  Assignments due in the next 7 days
  > Retrieval.query(3, [graded: true, scheduling_type: :due_by, end_date: [:between, DateTime.utc_now(), DateTime.utc_now() + 7]])

  Assignments that either have a time limit or a due date
  > Retrieval.query(3, [[graded: true, scheduling_type: :due_by], [graded: true, time_limit: [:not_eq, 0]]])
  """
  def query(section_id, conditions, field_list \\ nil) do



  end



end
