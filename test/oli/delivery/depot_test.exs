defmodule Oli.Delivery.DepotTest do

  use ExUnit.Case, async: true

  alias Oli.Delivery.Depot.Serializer
  alias Oli.Delivery.Depot.Match
  alias Oli.Delivery.Sections.SectionResource

  test "testing ets" do

    # create a 'bag' ets table
    table = :ets.new(:section_resources, [:bag, :protected])

    section_id = 1

    :ets.insert(table, [{section_id, 1, 11, false, "container", [12, 13], "slug1", "title", []},
                          {section_id, 2, 12, true, "page", [], "slug2", "title", []},
                          {section_id, 3, 13, false, "page", [], "slug3", "title", []}])

    assert :ets.lookup(table, section_id) == [{section_id, 1, 11, false, "container", [12, 13], "slug1", "title", []},
                                               {section_id, 2, 12, true, "page", [], "slug2", "title", []},
                                               {section_id, 3, 13, false, "page", [], "slug3", "title", []}]

    # do an ets search to find all pages in section_id = 1
    match_spec = [{{section_id, :_, :_, :_, "page", :_, :_, :_, :_}, [], [:"$_"]}]
    result = :ets.select(table, match_spec)

    #IO.inspect result

    match_spec = [{{section_id, :_, :_, true, "page", :_, :_, :_, :_}, [], [:"$_"]}]
    result = :ets.select(table, match_spec)

    #IO.inspect result

    match_spec = [{{section_id, :_, :_, :_, "container", :_, :_, :_, :_}, [], [:"$_"]}]
    result = :ets.select(table, match_spec)

    #IO.inspect(result, charlists: :as_lists)

  end

  test "testing serializer" do

    sr = %SectionResource{section_id: 1, id: 1}
    t = Serializer.serialize(sr)

    table = :ets.new(:section_resources, [:bag, :protected])
    :ets.insert(table, [t])

    r = :ets.lookup(table, 1)

    Serializer.unserialize(r)

    #match_spec = Match.build(1, scheduling_type: :read_by, late_submit: :allow)

    #:ets.select(table, [match_spec])
    #|> Serializer.unserialize()
    #|> IO.inspect()

    SectionResource.__schema__(:fields)
    |> Enum.map(fn f -> SectionResource.__schema__(:type, f) |> IO.inspect() end)
  end

end
