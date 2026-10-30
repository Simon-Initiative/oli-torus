defmodule Oli.Resources.ObjectiveIdsTest do
  use ExUnit.Case, async: true

  alias Oli.Resources.{ObjectiveIds, Revision}

  test "objective bindings accept empty bindings and positive bigint IDs" do
    for bindings <- [nil, %{}, %{"attached" => []}, %{"1" => [1, "2", 9_223_372_036_854_775_807]}] do
      assert ObjectiveIds.valid_bindings?(bindings)
      assert Revision.changeset(revision(), %{objectives: bindings}).valid?
    end
  end

  test "changed bindings reject malformed and out-of-range IDs" do
    for invalid <- [
          0,
          -1,
          1.5,
          true,
          nil,
          %{},
          [],
          "x",
          "1.2",
          "+1",
          "01",
          "9223372036854775808",
          9_223_372_036_854_775_808,
          String.duplicate("9", 100)
        ] do
      bindings = %{"1" => [invalid]}
      refute ObjectiveIds.valid_bindings?(bindings)

      assert Keyword.has_key?(
               Revision.changeset(revision(), %{objectives: bindings}).errors,
               :objectives
             )
    end

    for bindings <- [%{"1" => "1"}, %{"1" => %{}}, [1]] do
      refute ObjectiveIds.valid_bindings?(bindings)

      assert Keyword.has_key?(
               Revision.changeset(revision(), %{objectives: bindings}).errors,
               :objectives
             )
    end
  end

  test "unrelated edits do not reject existing legacy bindings" do
    assert Revision.changeset(%{revision() | objectives: %{"1" => ["legacy"]}}, %{graded: true}).valid?
  end

  defp revision do
    %Revision{
      title: "Existing",
      slug: "existing",
      author_id: 1,
      resource_id: 1,
      resource_type_id: 3,
      deleted: false
    }
  end
end
