defmodule Oli.Publishing.UniqueIdsTest do
  use ExUnit.Case, async: true
  alias Oli.Publishing.UniqueIds
  alias Oli.TestHelpers

  defp extract_ids(content) when is_list(content) do
    Enum.map(content, &extract_ids/1)
    |> List.flatten()
  end

  defp extract_ids(content) do
    {_, ids} =
      UniqueIds.map_reduce(
        content,
        [],
        fn e, ids, _tr_context ->
          {e, [Map.get(e, "id") | ids]}
        end,
        UniqueIds.traversal_context()
      )

    ids
  end

  defp extract_ids_from(original, updated, func) do
    original_ids = func.(original) |> extract_ids() |> Enum.frequencies()
    updated_ids = func.(updated) |> extract_ids() |> Enum.frequencies()
    {original_ids, updated_ids}
  end

  test "uniqueify/3 handles page content correctly" do
    {:ok, content} = TestHelpers.read_json_file("./test/oli/publishing/page.json")

    # Extract all of the "id" attributes from the content
    # and count how many times each one appears.
    counts_before =
      extract_ids(content)
      |> Enum.frequencies()

    assert Map.get(counts_before, nil) == 7
    assert Map.get(counts_before, "1") == 7
    total = Enum.reduce(counts_before, 0, fn {_, count}, acc -> acc + count end)
    assert total == 22

    # Now uniqueify the ids in the content and count the "id" attributes again.
    updated = UniqueIds.uniqueify(content, Oli.Resources.ResourceType.get_id_by_type("page"), 1)

    counts_after =
      extract_ids(updated)
      |> Enum.frequencies()

    refute Map.has_key?(counts_after, nil)
    assert Map.get(counts_after, "1") == 1
    total = Enum.reduce(counts_after, 0, fn {_, count}, acc -> acc + count end)

    # This is the key couple of assertions - here we verify that the the
    # total number of unique ids is the same as their total frequency (i.e.,
    # every id is unique and appears only once in the content tree)
    assert total == 22
    assert Map.keys(counts_after) |> Enum.count() == 22
  end

  test "uniqueify/3 handles activity content correctly" do
    {:ok, content} = TestHelpers.read_json_file("./test/oli/publishing/activity.json")

    updated =
      UniqueIds.uniqueify(content, Oli.Resources.ResourceType.get_id_by_type("activity"), 1)

    {original_ids, updated_ids} =
      extract_ids_from(content, updated, fn content -> content["stem"]["content"] end)

    assert original_ids["1"] == 3
    assert updated_ids["1"] == 2
    assert Map.keys(updated_ids) |> Enum.count() == 2

    assert Jason.encode!(updated)
           |> String.split("\"id\":\"1\"")
           |> Enum.count() == 3

    # verify that the "id" of the part remains unchanged
    part = updated["authoring"]["parts"] |> Enum.at(0)
    assert part["id"] == "this_cannot_change"

    # verfiy that the "id" of the input_ref remains unchanged
    input_ref = updated["stem"]["content"] |> Enum.at(2)
    assert input_ref["id"] == "1"
  end
end
