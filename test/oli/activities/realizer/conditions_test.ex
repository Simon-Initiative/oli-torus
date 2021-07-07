defmodule Oli.Activities.ConditionsTest do
  use ExUnit.Case, async: true

  alias Oli.Activities.Realizer.Conditions
  alias Oli.TestHelpers

  test "parsing conditions with just an expression" do
    {:ok, contents} = TestHelpers.read_json_file("./test/oli/activities/realizer/valid1.json")

    assert {:ok, parsed} = Conditions.parse(contents)

    assert parsed.conditions.fact == :tags
    assert parsed.conditions.operator == :contains
    assert parsed.conditions.value == [1]
  end

  test "parsing conditions with a clause and two children expressions" do
    {:ok, contents} = TestHelpers.read_json_file("./test/oli/activities/realizer/valid2.json")

    assert {:ok, parsed} = Conditions.parse(contents)

    assert parsed.conditions.operator == :all

    assert Enum.at(parsed.conditions.children, 0).fact == :tags
    assert Enum.at(parsed.conditions.children, 0).operator == :does_not_contain
    assert Enum.at(parsed.conditions.children, 0).value == [1]

    assert Enum.at(parsed.conditions.children, 1).fact == :objectives
    assert Enum.at(parsed.conditions.children, 1).operator == :equals
    assert Enum.at(parsed.conditions.children, 1).value == [2]

    assert Enum.at(parsed.conditions.children, 2).fact == :type
    assert Enum.at(parsed.conditions.children, 2).operator == :does_not_equal
    assert Enum.at(parsed.conditions.children, 2).value == 3

    assert Enum.at(parsed.conditions.children, 3).fact == :text
    assert Enum.at(parsed.conditions.children, 3).operator == :contains
    assert Enum.at(parsed.conditions.children, 3).value == "test"
  end

  test "parsing conditions nested clauses" do
    {:ok, contents} = TestHelpers.read_json_file("./test/oli/activities/realizer/valid3.json")

    assert {:ok, parsed} = Conditions.parse(contents)

    assert parsed.conditions.operator == :all
    assert Enum.at(parsed.conditions.children, 0).operator == :any
    assert Enum.at(parsed.conditions.children, 1).operator == :any
  end

  test "parsing fails when encountering bad combination of " do
    {:ok, contents} = TestHelpers.read_json_file("./test/oli/activities/realizer/invalid1.json")
    assert {:error, e} = Conditions.parse(contents)
    assert e == "invalid expression"
  end
end
