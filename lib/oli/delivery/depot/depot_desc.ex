defmodule Oli.Delivery.Depot.DepotDesc do

  @required_fields [:name, :schema, :table, :key_field]

  defstruct [
    name: nil,
    schema: nil,
    table: nil,
    key_field: nil
  ]

end
