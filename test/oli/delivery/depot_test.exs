defmodule Oli.Delivery.DepotTest do

  use ExUnit.Case, async: true

  alias Oli.Delivery.Depot
  alias Oli.Delivery.Depot.DepotDesc

  defmodule R do
    use Ecto.Schema

    schema "fake_schema" do
      field(:title, :string)
      field(:section_id, :integer)
      field(:graded, :boolean)
      field(:created, :utc_datetime)
    end
  end

  def r({id, section_id, title, graded, created}) do
    %R{
      id: id,
      section_id: section_id,
      title: title,
      graded: graded,
      created: created
    }
  end

  @desc %DepotDesc{
    name: "test",
    schema: R,
    table_name_prefix: :test,
    key_field: :id,
    table_id_field: :section_id
  }

  test "table exists" do

    refute Depot.table_exists?(@desc, 1)
    Depot.create_table(@desc, 1)
    assert Depot.table_exists?(@desc, 1)

  end

  test "testing update" do

    # Create a table with a single record
    Depot.create_table(@desc, 1)
    Depot.update(@desc, r({1, 1, "one", false, DateTime.utc_now()}))
    assert [%R{id: 1, title: "one", graded: false}] = Depot.all(@desc, 1)

    # Now issue an update and verify that the record has been updated
    # with the new values, and not duplicated
    Depot.update(@desc, r({1, 1, "update", true, DateTime.utc_now()}))
    assert [%R{id: 1, title: "update", graded: true}] = Depot.all(@desc, 1)

  end

  test "testing update_all" do

    # Create a table with a single record
    Depot.create_table(@desc, 1)
    Depot.update(@desc, r({1, 1, "one", false, DateTime.utc_now()}))
    assert [%R{id: 1, title: "one", graded: false}] = Depot.all(@desc, 1)

    # Now issue an update_all to update that record and insert a second
    Depot.update_all(@desc, [
      r({1, 1, "update", true, DateTime.utc_now()}),
      r({2, 1, "second", true, DateTime.utc_now()})
    ])
    assert [
      %R{id: 1, title: "update", graded: true},
      %R{id: 2, title: "second", graded: true}
    ] = Depot.all(@desc, 1) |> Enum.sort_by(&(&1.id))

  end

  test "clear_and_set" do

    # Create a table with a couple of records
    Depot.create_table(@desc, 1)

    Depot.update_all(@desc, [
      r({1, 1, "1", true, DateTime.utc_now()}),
      r({2, 1, "2", true, DateTime.utc_now()})
    ])
    assert [
      %R{id: 1, title: "1", graded: true},
      %R{id: 2, title: "2", graded: true}
    ] = Depot.all(@desc, 1) |> Enum.sort_by(&(&1.id))

    # Now issue a clear_and_set to replace the records
    Depot.clear_and_set(@desc, 1, [
      r({3, 1, "3", false, DateTime.utc_now()}),
      r({4, 1, "4", false, DateTime.utc_now()})
    ])
    assert [
      %R{id: 3, title: "3", graded: false},
      %R{id: 4, title: "4", graded: false}
    ] = Depot.all(@desc, 1) |> Enum.sort_by(&(&1.id))
  end

  test "get" do

    # Create a table with a couple of records
    Depot.create_table(@desc, 1)

    Depot.update_all(@desc, [
      r({1, 1, "1", true, DateTime.utc_now()}),
      r({2, 1, "2", true, DateTime.utc_now()})
    ])
    assert [
      %R{id: 1, title: "1", graded: true},
      %R{id: 2, title: "2", graded: true}
    ] = Depot.all(@desc, 1) |> Enum.sort_by(&(&1.id))

    # Now get each of them individually
    assert %R{id: 1, title: "1", graded: true} = Depot.get(@desc, 1, 1)
    assert %R{id: 2, title: "2", graded: true} = Depot.get(@desc, 1, 2)
  end


  test "query" do

    # Create a table with a few records
    Depot.create_table(@desc, 1)

    Depot.update_all(@desc, [
      r({1, 1, "1", true, DateTime.utc_now()}),
      r({2, 1, "2", false, DateTime.utc_now()}),
      r({3, 1, "3", true, DateTime.utc_now()}),
      r({4, 1, "4", false, DateTime.utc_now()})
    ])
    assert [
      %R{id: 1, title: "1", graded: true},
      %R{id: 2, title: "2", graded: false},
      %R{id: 3, title: "3", graded: true},
      %R{id: 4, title: "4", graded: false}
    ] = Depot.all(@desc, 1) |> Enum.sort_by(&(&1.id))

    # Now do some querying
    assert [
      %R{id: 1, title: "1", graded: true},
      %R{id: 3, title: "3", graded: true}
    ] = Depot.query(@desc, 1, [graded: true]) |> Enum.sort_by(&(&1.id))

    assert [
      %R{id: 2, title: "2", graded: false},
      %R{id: 4, title: "4", graded: false}
    ] = Depot.query(@desc, 1, [graded: false]) |> Enum.sort_by(&(&1.id))

    assert [
      %R{id: 2, title: "2", graded: false}
    ] = Depot.query(@desc, 1, [graded: false, title: "2"])

  end

end
