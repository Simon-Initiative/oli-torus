defmodule Oli.Delivery.Depot.MatchSpecTranslatorTest do

  use ExUnit.Case, async: true

  alias Oli.Delivery.Depot.MatchSpecTranslator
  alias Oli.Delivery.Depot.DepotDesc

  test "testing ets" do

    table = :ets.new(:test, [:set, :protected])

    defmodule FakeSchema do
      use Ecto.Schema

      schema "fake_schema" do
        field(:title, :string)
        field(:duration, :integer)
        field(:graded, :boolean)
        field(:created, :utc_datetime)
      end
    end

    depot_desc = %DepotDesc{
      name: "test",
      schema: FakeSchema,
      table_name_prefix: :test,
      key_field: :id,
      table_id_field: :duration
    }


    day1 = DateTime.from_naive!(~N[2024-01-01 00:00:00.000], "Etc/UTC") |> DateTime.to_unix(:millisecond)
    day2 = DateTime.from_naive!(~N[2024-01-15 00:00:00.000], "Etc/UTC") |> DateTime.to_unix(:millisecond)
    day3 = DateTime.from_naive!(~N[2024-01-31 00:00:00.000], "Etc/UTC") |> DateTime.to_unix(:millisecond)

    record1 = {1, 1, "one", 1, false, day1}
    record2 = {2, 2, "two", 2, true, day2}
    record3 = {3, 3, "three", 1, false, day3}

    :ets.insert(table, [record1, record2, record3])

    assert [^record2] = :ets.select(table, [MatchSpecTranslator.translate(depot_desc, duration: 2)])
    assert [^record1] = :ets.select(table, [MatchSpecTranslator.translate(depot_desc, duration: 1, title: "one")])
    assert [^record2] = :ets.select(table, [MatchSpecTranslator.translate(depot_desc, {:duration, {:>, 1}})])
    assert [^record1, ^record2, ^record3] = :ets.select(table, [MatchSpecTranslator.translate(depot_desc, {:duration, {:in, [1, 2, 3]}})])
    |> Enum.sort()

    assert [^record2] = :ets.select(table, [MatchSpecTranslator.translate(depot_desc, {:duration, {:between, 1, 3}})])

    assert [^record2, ^record3] = :ets.select(table, [MatchSpecTranslator.translate(depot_desc, {:created, {:>, DateTime.from_naive!(~N[2024-01-10 00:00:00.000], "Etc/UTC")}})])
    |> Enum.sort()

    d1 = DateTime.from_naive!(~N[2024-01-10 00:00:00.000], "Etc/UTC")
    d2 = DateTime.from_naive!(~N[2024-01-18 00:00:00.000], "Etc/UTC")
    assert [^record2] = :ets.select(table, [MatchSpecTranslator.translate(depot_desc, {:created, {:between, d1, d2}})])

  end

end
