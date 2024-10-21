defmodule Oli.Delivery.Depot.DepotDesc do
  @enforce_keys [:name, :schema, :table_name_prefix, :key_field, :table_id_field]

  defstruct name: nil,
            schema: nil,
            table_name_prefix: nil,
            key_field: nil,
            table_id_field: nil

  def table_name(depot_desc, value) do
    "#{depot_desc.table_name_prefix}_#{value}" |> String.to_atom()
  end
end
