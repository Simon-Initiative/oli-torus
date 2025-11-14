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

  def selection(count, expressions, operator \\ :all) do
    %Selection{
      count: count,
      points_per_activity: 1.0,
      logic: %Logic{
        conditions: %Clause{
          operator: operator,
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

    # contains [2] should match any activity that has objective 2 (OR logic)
    selection = selection(2, [expression(:objectives, :contains, [2])])
    {:partial, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 1
    assert Enum.at(result.rows, 0).resource_id == 2

    # contains [1, 2] should match any activity that has objective 1 OR 2 (both activities)
    selection = selection(2, [expression(:objectives, :contains, [1, 2])])
    {:ok, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 2

    # contains [1] should match any activity that has objective 1 (both activities)
    selection = selection(2, [expression(:objectives, :contains, [1])])
    {:ok, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 2

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

    # does_not_contain [2] should match activities that don't have objective 2
    selection = selection(2, [expression(:objectives, :does_not_contain, [2])])
    {:partial, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 1
    assert Enum.at(result.rows, 0).resource_id == 2

    # does_not_contain [1] should match activities that don't have objective 1 (none)
    selection = selection(2, [expression(:objectives, :does_not_contain, [1])])
    {:partial, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 0

    # does_not_contain [1, 2] should match activities that have neither 1 nor 2 (none)
    selection = selection(2, [expression(:objectives, :does_not_contain, [1, 2])])
    {:partial, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 0

    # does_not_contain [3] should match all activities (none have objective 3)
    selection = selection(2, [expression(:objectives, :does_not_contain, [3])])
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

    # contains [2] matches both activities, but resource_id 1 is blacklisted
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

    # Multiple expressions with ALL operator - both conditions must be true
    # contains [2] matches both activities (OR logic), but contains [4] only matches resource_id 2
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

  test "multiple expressions with ANY operator" do
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

    # Testing with ALL: both conditions must be true
    # contains [2] matches both, contains [4] matches only resource_id 2
    # Result: only resource_id 2 matches both
    selection =
      selection(
        2,
        [expression(:objectives, :contains, [2]), expression(:tags, :contains, [4])],
        :all
      )

    {:partial, result} = Selection.fulfill(selection, source)
    assert length(result.rows) == 1

    # Testing with ANY: at least one condition must be true
    # contains [2] matches both activities, contains [4] matches resource_id 2
    # Result: both activities match (both have objective 2)
    selection =
      selection(
        2,
        [expression(:objectives, :contains, [2]), expression(:tags, :contains, [4])],
        :any
      )

    {:ok, result} = Selection.fulfill(selection, source)

    assert length(result.rows) == 2
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
