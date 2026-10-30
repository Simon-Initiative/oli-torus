defmodule Oli.Auditing.EntityIdTest do
  use ExUnit.Case, async: true

  alias Oli.Auditing.EntityId

  doctest EntityId

  test "composes and parses ordered segments" do
    id = EntityId.compose(section: 301, resource: 4512, user: 77)

    assert id == "section:301/resource:4512/user:77"
    assert EntityId.parse(id) == {:ok, [{"section", "301"}, {"resource", "4512"}, {"user", "77"}]}
  end

  test "rejects segments that would make the ID ambiguous" do
    assert_raise ArgumentError, fn -> EntityId.compose(section: "3/01") end
    assert_raise ArgumentError, fn -> EntityId.compose(section: "a:b") end
  end

  test "rejects malformed text" do
    assert EntityId.parse("section") == :error
    assert EntityId.parse("Section:1") == :error
    assert EntityId.parse("section:1//user:2") == :error
  end
end
