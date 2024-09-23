defmodule Oli.Delivery.Depot.MatchSpecTranslatorTest do

  use ExUnit.Case, async: true

  alias Oli.Delivery.Depot.MatchSpecTranslator

  test "testing ets" do

    # create a 'bag' ets table
    table = :ets.new(:test, [:bag, :protected])

    key = 1
    field_types = [{:title, :string}, {:duration, :integer}, {:graded, :boolean}, {:created, :utc_datetime}]

    day1 = DateTime.from_naive!(~N[2024-01-01 00:00:00.000], "Etc/UTC")
    day2 = DateTime.from_naive!(~N[2024-01-15 00:00:00.000], "Etc/UTC")
    day3 = DateTime.from_naive!(~N[2024-01-31 00:00:00.000], "Etc/UTC")

    record1 = {key, "one", 1, false, day1}
    record2 = {key, "two", 2, true, day2}
    record3 = {key, "three", 1, false, day3}

    :ets.insert(table, [record1, record2, record3])

    assert [^record2] = :ets.select(table, [MatchSpecTranslator.translate(field_types, key, duration: 2)])
    assert [^record1] = :ets.select(table, [MatchSpecTranslator.translate(field_types, key, duration: 1, title: "one")])
    assert [^record2] = :ets.select(table, [MatchSpecTranslator.translate(field_types, key, {:duration, {:>, 1}})])
    assert [^record1, ^record2, ^record3] = :ets.select(table, [MatchSpecTranslator.translate(field_types, key, {:duration, {:in, [1, 2, 3]}})])



  end

end
