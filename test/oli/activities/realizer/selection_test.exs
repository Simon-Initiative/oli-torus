defmodule Oli.Activities.SelectionTest do
  use ExUnit.Case, async: true

  alias Oli.Activities.Realizer.Logic
  alias Oli.Activities.Realizer.Selection
  alias Oli.Activities.Realizer.Query.BankEntry
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Activities.Realizer.Logic.Expression
  alias Oli.Activities.Realizer.Logic.Clause

  def expression(fact, operator, value) do
    %Expression{
      fact: fact,
      operator: operator,
      value: value
    }
  end

  def selection(count, expressions) do
    %Selection{
      count: count,
      logic: %Logic{
        conditions: %Clause{
          operator: :all,
          children: expressions
        }
      },
      id: 1,
      purpose: "test",
      type: "test"
    }
  end

  test "equals" do
    source = %Source{
      bank: [
        %BankEntry{
          resource_id: 1,
          objectives: MapSet.new([1, 2]),
          tags: MapSet.new([1, 2]),
          activity_type_id: 1
        },
        %BankEntry{
          resource_id: 2,
          objectives: MapSet.new([2]),
          tags: MapSet.new([1, 2]),
          activity_type_id: 1
        }
      ],
      blacklisted_activity_ids: [],
      publication_id: 1,
      section_slug: ""
    }

    selection = selection(2, [expression(:objectives, :equals, [2])])
    {:partial, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 1
    assert Enum.at(result.rows, 0).resource_id == 2

    selection = selection(2, [expression(:objectives, :equals, [2, 1])])
    {:partial, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 1
    assert Enum.at(result.rows, 0).resource_id == 1

    selection = selection(2, [expression(:objectives, :equals, [4])])
    {:partial, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 0
  end

  test "does not equal" do
    source = %Source{
      bank: [
        %BankEntry{
          resource_id: 1,
          objectives: MapSet.new([1, 2]),
          tags: MapSet.new([1, 2]),
          activity_type_id: 1
        },
        %BankEntry{
          resource_id: 2,
          objectives: MapSet.new([2]),
          tags: MapSet.new([1, 2]),
          activity_type_id: 1
        }
      ],
      blacklisted_activity_ids: [],
      publication_id: 1,
      section_slug: ""
    }

    selection = selection(2, [expression(:objectives, :does_not_equal, [1, 2])])
    {:partial, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 1
    assert Enum.at(result.rows, 0).resource_id == 2

    selection = selection(2, [expression(:objectives, :does_not_equal, [2])])
    {:partial, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 1
    assert Enum.at(result.rows, 0).resource_id == 1

    selection = selection(2, [expression(:objectives, :does_not_equal, [4])])
    {:ok, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 2
  end

  test "contains" do
    source = %Source{
      bank: [
        %BankEntry{
          resource_id: 1,
          objectives: MapSet.new([1]),
          tags: MapSet.new([1, 2]),
          activity_type_id: 1
        },
        %BankEntry{
          resource_id: 2,
          objectives: MapSet.new([1, 2]),
          tags: MapSet.new([1, 2]),
          activity_type_id: 1
        }
      ],
      blacklisted_activity_ids: [],
      publication_id: 1,
      section_slug: ""
    }

    selection = selection(2, [expression(:objectives, :contains, [2])])
    {_, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 1
    assert Enum.at(result.rows, 0).resource_id == 2

    selection = selection(2, [expression(:objectives, :contains, [1, 2])])
    {:partial, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 1
    assert Enum.at(result.rows, 0).resource_id == 2

    selection = selection(2, [expression(:objectives, :contains, [4])])
    {:partial, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 0
  end

  test "does not contain" do
    source = %Source{
      bank: [
        %BankEntry{
          resource_id: 1,
          objectives: MapSet.new([1, 2]),
          tags: MapSet.new([1, 2]),
          activity_type_id: 1
        },
        %BankEntry{
          resource_id: 2,
          objectives: MapSet.new([1]),
          tags: MapSet.new([1, 2]),
          activity_type_id: 1
        }
      ],
      blacklisted_activity_ids: [],
      publication_id: 1,
      section_slug: ""
    }

    selection = selection(2, [expression(:objectives, :does_not_contain, [2])])
    {:partial, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 1
    assert Enum.at(result.rows, 0).resource_id == 2

    selection = selection(2, [expression(:objectives, :does_not_contain, [1])])
    {:partial, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 0

    selection = selection(2, [expression(:objectives, :does_not_contain, [1, 2, 3])])
    {:ok, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 2
  end

  test "blacklisting" do
    source = %Source{
      bank: [
        %BankEntry{
          resource_id: 1,
          objectives: MapSet.new([1, 2]),
          tags: MapSet.new([1, 2]),
          activity_type_id: 1
        },
        %BankEntry{
          resource_id: 2,
          objectives: MapSet.new([2]),
          tags: MapSet.new([1, 2]),
          activity_type_id: 1
        }
      ],
      blacklisted_activity_ids: [1],
      publication_id: 1,
      section_slug: ""
    }

    selection = selection(2, [expression(:objectives, :contains, [2])])
    {:partial, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 1
    assert Enum.at(result.rows, 0).resource_id == 2
  end

  test "multiple expressions" do
    source = %Source{
      bank: [
        %BankEntry{
          resource_id: 1,
          objectives: MapSet.new([1, 2]),
          tags: MapSet.new([3]),
          activity_type_id: 1
        },
        %BankEntry{
          resource_id: 2,
          objectives: MapSet.new([2]),
          tags: MapSet.new([4]),
          activity_type_id: 1
        }
      ],
      blacklisted_activity_ids: [],
      publication_id: 1,
      section_slug: ""
    }

    selection =
      selection(2, [expression(:objectives, :contains, [2]), expression(:tags, :contains, [4])])

    {:partial, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 1
    assert Enum.at(result.rows, 0).resource_id == 2
  end

  test "multiple expressions AND blacklisting" do
    source = %Source{
      bank: [
        %BankEntry{
          resource_id: 1,
          objectives: MapSet.new([1, 2]),
          tags: MapSet.new([3]),
          activity_type_id: 1
        },
        %BankEntry{
          resource_id: 2,
          objectives: MapSet.new([2]),
          tags: MapSet.new([4]),
          activity_type_id: 1
        }
      ],
      blacklisted_activity_ids: [2],
      publication_id: 1,
      section_slug: ""
    }

    selection =
      selection(2, [expression(:objectives, :contains, [2]), expression(:tags, :contains, [4])])

    {:partial, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 0
  end

  test "item type contains" do
    source = %Source{
      bank: [
        %BankEntry{
          resource_id: 1,
          objectives: MapSet.new([1, 2]),
          tags: MapSet.new([1, 2]),
          activity_type_id: 1
        },
        %BankEntry{
          resource_id: 2,
          objectives: MapSet.new([2]),
          tags: MapSet.new([1, 2]),
          activity_type_id: 2
        }
      ],
      blacklisted_activity_ids: [],
      publication_id: 1,
      section_slug: ""
    }

    selection = selection(2, [expression(:type, :contains, [1, 2])])
    {:ok, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 2
  end

  test "item type does not contains" do
    source = %Source{
      bank: [
        %BankEntry{
          resource_id: 1,
          objectives: MapSet.new([1, 2]),
          tags: MapSet.new([1, 2]),
          activity_type_id: 1
        },
        %BankEntry{
          resource_id: 2,
          objectives: MapSet.new([2]),
          tags: MapSet.new([1, 2]),
          activity_type_id: 2
        }
      ],
      blacklisted_activity_ids: [],
      publication_id: 1,
      section_slug: ""
    }

    selection = selection(2, [expression(:type, :does_not_contain, [2, 4])])
    {:partial, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 1
  end

  test "item type equals" do
    source = %Source{
      bank: [
        %BankEntry{
          resource_id: 1,
          objectives: MapSet.new([1, 2]),
          tags: MapSet.new([1, 2]),
          activity_type_id: 1
        },
        %BankEntry{
          resource_id: 2,
          objectives: MapSet.new([2]),
          tags: MapSet.new([1, 2]),
          activity_type_id: 2
        }
      ],
      blacklisted_activity_ids: [],
      publication_id: 1,
      section_slug: ""
    }

    selection = selection(2, [expression(:type, :equals, 2)])
    {:partial, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 1
    assert Enum.at(result.rows, 0).resource_id == 2
  end

  test "item type does not equals" do
    source = %Source{
      bank: [
        %BankEntry{
          resource_id: 1,
          objectives: MapSet.new([1, 2]),
          tags: MapSet.new([1, 2]),
          activity_type_id: 1
        },
        %BankEntry{
          resource_id: 2,
          objectives: MapSet.new([2]),
          tags: MapSet.new([1, 2]),
          activity_type_id: 2
        }
      ],
      blacklisted_activity_ids: [],
      publication_id: 1,
      section_slug: ""
    }

    selection = selection(2, [expression(:type, :does_not_equal, 2)])
    {:partial, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 1
    assert Enum.at(result.rows, 0).resource_id == 1
  end
end
