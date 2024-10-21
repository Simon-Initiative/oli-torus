defmodule Oli.Delivery.Depot.MatchSpecTranslator do
  alias Oli.Delivery.Depot.DepotDesc

  @moduledoc """
  Translates the depot's outward facing conditional query syntax into match specs for ETS.

  This is agnostic to any specific schema.
  """

  @doc """

  Convert the given field types, key, conditions, and return fields into a match spec for ETS.

  The target format is a tuple of the form:
  {match_spec, guards, return_fields}

  This implementation optimizes to place simple equality conditions to be captured directly
  within the match spec, and more complex conditions to be captured within the guards. This
  is done to minimize the number of times the guards are evaluated, which optimizes retrieval.

  Example (return only the titles where the duration equals 10):

  > translate([{:title, :string}, {:duration, :integer}], [duration: 10], [:title])
  {{1, :"$f1", 10}, [], [:"$f1"]}

  Example (return all fields where the duration is between 5 and 10):

  > translate([{:title, :string}, {:duration, :integer}], [{:duration, {:between, 5, 10}}], nil)
  {{1, :_, :"$f1"}, [{:andalso, {:>, :"$f1", 5}, {:<, :"$f1", 10}}], [:"$_"]}

  Example (return all fields where the duration is 5 and the title is "foo"):

  > translate([{:title, :string}, {:duration, :integer}], duration: 5, title: "foo")
  {{1, "foo", 5}, [], [:"$_"]}


  field_types: list of tuples of field names and their types {:title, :string}

  key: the key of the match spec

  conditions: list of conditions to match of the form [{key, value}]

    Supported conditions:
      :==, :!=, :<, :>, :<=, :>=, :between, :in, where the last two are special cases
      in that they require two values or a list of values, respectively.

  return_fields: list of fields to return, or nil if all fields should be returned
  """
  def translate(depot_desc, conditions, fields_to_return \\ [])

  def translate(%DepotDesc{} = depot_desc, conditions, fields_to_return)
      when is_tuple(conditions) do
    translate(depot_desc, [conditions], fields_to_return)
  end

  def translate(%DepotDesc{} = depot_desc, conditions, fields_to_return) do
    field_types = build_field_pairs(depot_desc.schema)

    condition_fields =
      Enum.reduce(conditions, MapSet.new(), fn {key, _}, acc ->
        MapSet.put(acc, key)
      end)

    conditions_by_field =
      Enum.reduce(conditions, %{}, fn {key, _} = c, acc ->
        Map.put(acc, key, c)
      end)

    return_fields =
      Enum.reduce(fields_to_return, MapSet.new(), fn key, acc ->
        MapSet.put(acc, key)
      end)

    {m, c, f, _} =
      Enum.reduce(field_types, {[], [], %{}, 0}, fn {field_name, type}, {m, c, f, v} ->
        in_condition = MapSet.member?(condition_fields, field_name)
        in_return = MapSet.member?(return_fields, field_name)
        in_either = in_condition or in_return

        condition = Map.get(conditions_by_field, field_name)

        {m, v} =
          if in_either do
            {[field(v + 1) | m], v + 1}
          else
            {[:_ | m], v}
          end

        {m, c, v} =
          if in_condition do
            handle_cond(type, condition, in_return, {m, c, v})
          else
            {m, c, v}
          end

        f =
          if in_return do
            Map.put(f, field_name, field(v))
          else
            f
          end

        {m, c, f, v}
      end)

    # Order the return fields spec to match the order of the fields as requested by 'return_fields'
    # handling the case that if none were specified, in which case we return all fields using the
    # ETS specific syntax for that.
    f =
      case fields_to_return do
        nil -> [:"$_"]
        [] -> [:"$_"]
        _ -> Enum.map(return_fields, fn field_name -> Map.get(f, field_name) end)
      end

    # Reverse the fields (since we chose to prepend them as an optimization)
    # tacking on the required slot for the key and convert to the necessary tuple format
    m = [:_ | Enum.reverse(m)] |> List.to_tuple()

    # The order of the conditions does not matter, so we don't bother to reorder them
    {m, c, f}
  end

  # The :between operator is a special case, as it requires two values
  defp handle_cond(type, {_f, {:between, value1, value2}}, _, {m, c, v}) do
    {m,
     [{:andalso, {:>, field(v), encode(value1, type)}, {:<, field(v), encode(value2, type)}} | c],
     v}
  end

  # The :in operator is a special case as we map the values of the list to multiple
  # :orelse equality conditions
  defp handle_cond(type, {_f, {:in, value}}, _, {m, c, v}) do
    {:orelse, {:==, :"$1", 1}, {:orelse, {:==, :"$1", 2}, {:==, :"$1", 3}}}

    case Enum.count(value) do
      0 ->
        {m, c, v}

      1 ->
        {m, [{:==, field(v), encode(Enum.at(value, 0), type)} | c], v}

      _ ->
        # Build a recursive tuple of :orelse clauses like:
        # {:orelse, {:==, :"$1", 3}, {:orelse, {:==, :"$1", 1}, {:==, :"$1", 2}}}
        first_two = Enum.take(value, 2)

        initial =
          {:orelse, {:==, field(v), encode(Enum.at(first_two, 0), type)},
           {:==, field(v), encode(Enum.at(first_two, 1), type)}}

        or_else =
          Enum.drop(value, 2)
          |> Enum.reduce(initial, fn value, acc ->
            Tuple.append({:orelse, {:==, field(v), encode(value, type)}}, acc)
          end)

        {m, [or_else | c], v}
    end
  end

  # Handles the cases where we have {operator, value} tuples, and the
  # operators are from a set that we can translate directly to ETS match spec operators
  # (which are :==, :!=, :<, :>, :<=, :>=)
  defp handle_cond(type, {_f, {op, value}}, _, {m, c, v}) do
    {m, [{op, field(v), encode(value, type)} | c], v}
  end

  # Finally the shortcut syntax for equality conditions.  Here we conditionally
  # change the already preprended field name to the direct value if this field
  # does not also appear in the return fields list.  If it does appear, we delegate
  # to the handle_cond function to handle the equality condition.
  defp handle_cond(type, {_field, value}, true, {m, c, v}) do
    handle_cond(type, {:==, value}, true, {m, c, v})
  end

  defp handle_cond(type, {_field, value}, false, {m, c, v}) do
    [_field_binder | rest] = m
    {[encode(value, type) | rest], c, v}
  end

  defp field(v), do: :"$#{v}"

  defp encode(value, :utc_datetime) do
    DateTime.to_unix(value, :millisecond)
  end

  defp encode(value, _), do: value

  defp build_field_pairs(schema) do
    apply(schema, :__schema__, [:fields])
    |> Enum.map(fn field -> {field, apply(schema, :__schema__, [:type, field])} end)
  end
end
