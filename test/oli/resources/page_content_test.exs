defmodule Oli.Resources.PageContentTest do
  use ExUnit.Case, async: true

  alias Oli.TestHelpers
  alias Oli.Resources.PageContent

  @basic_content %{
    "model" => [
      %{"type" => "content", "children" => [%{"type" => "p"}]},
      %{
        "type" => "survey",
        "id" => "00001",
        "children" => [
          %{"type" => "activity-reference", "activity_id" => 1}
        ]
      },
      %{
        "type" => "group",
        "id" => "00002",
        "layout" => "deck",
        "children" => [
          %{
            "type" => "survey",
            "id" => "00003",
            "children" => [
              %{"type" => "activity-reference", "activity_id" => 2},
              %{"type" => "activity-reference", "activity_id" => 3}
            ]
          },
          %{"type" => "activity-reference", "activity_id" => 4},
          %{"type" => "content", "children" => [%{"type" => "p"}]},
          %{"type" => "activity-reference", "activity_id" => 5}
        ]
      },
      %{"type" => "activity-reference", "activity_id" => 6}
    ]
  }

  @advanced_content %{
    "model" => [
      %{
        "type" => "group",
        "id" => "00001",
        "layout" => "deck",
        "children" => [
          %{
            "type" => "group",
            "id" => "00002",
            "layout" => "vertical",
            "children" => [
              %{"type" => "activity-reference", "activity_id" => 1},
              %{"type" => "activity-reference", "activity_id" => 2},
              %{"type" => "activity-reference", "activity_id" => 3}
            ]
          },
          %{"type" => "activity-reference", "activity_id" => 4},
          %{"type" => "content", "children" => [%{"type" => "p"}]},
          %{"type" => "activity-reference", "activity_id" => 5}
        ]
      }
    ],
    "advancedDelivery" => true
  }

  describe "reduce support" do
    test "it reduces all nodes, except top level 'model'" do
      assert {_, 8} =
               PageContent.map_reduce(@advanced_content, 0, fn item, acc, _tr_context ->
                 {item, acc + 1}
               end)
    end
  end

  describe "map support via map_reduce" do
    test "it numbers all the nodes" do
      {item, _acc} =
        PageContent.map_reduce(@advanced_content, 0, fn item, acc, _tr_context ->
          {Map.put(item, "id", acc + 1), acc + 1}
        end)

      activity4 = item["model"] |> Enum.at(0) |> Map.get("children") |> Enum.at(1)
      assert activity4["id"] == 5
    end
  end

  describe "flat filter support" do
    test "it flattens and filters all activity references" do
      refs =
        PageContent.flat_filter(@advanced_content, fn item ->
          Map.get(item, "type") == "activity-reference"
        end)

      assert length(refs) == 5
      assert Enum.all?(refs, fn a -> Map.get(a, "type") == "activity-reference" end)
      assert 15 = Enum.reduce(refs, 0, fn %{"activity_id" => id}, total -> total + id end)
    end
  end

  describe "map support via map" do
    test "it adds" do
      item = PageContent.map(@advanced_content, fn item -> Map.put(item, "id", 1) end)

      activity4 = item["model"] |> Enum.at(0) |> Map.get("children") |> Enum.at(1)
      assert activity4["id"] == 1
    end
  end

  describe "activity_parent_groups" do
    test "returns a mapping of all activities to parent groups and surveys" do
      mapping = PageContent.activity_parent_groups(@basic_content)

      assert mapping[1] === %{group: nil, survey: "00001"}
      assert mapping[2] === %{group: "00002", survey: "00003"}
      assert mapping[3] === %{group: "00002", survey: "00003"}
      assert mapping[4] === %{group: "00002", survey: nil}
      assert mapping[5] === %{group: "00002", survey: nil}
      assert mapping[6] === %{group: nil, survey: nil}
    end
  end

  describe "survey_activities" do
    test "returns a mapping of all surveys to the activities they contain" do
      mapping = PageContent.survey_activities(@basic_content)

      assert mapping["00001"] === [1]
      assert mapping["00002"] === nil
      assert mapping["00003"] === [3, 2]
    end
  end

  # map_reduce descending into structured content, as PageContent.map_reduce does not
  defp map_reduce_all_content(content, init_acc, map_fn) do
    PageContent.map_reduce(content, init_acc, fn item, acc, tr_context ->
      case item do
        %{"type" => "content"} ->
          PageContent.visit_children(item, acc, map_fn)

        _other ->
          map_fn.(item, acc, tr_context)
      end
    end)
  end

  # get all id values w/o using traversal functions under test
  defp extract_ids(content) do
    json = Jason.encode!(content)

    Regex.scan(~r/"id": ?"([^"]+)"/, json, capture: :all_but_first)
    |> List.flatten()
  end

  describe "map_property_content" do
    test "reaches content in img and popup properties" do
      {:ok, %{"content" => content}} =
        TestHelpers.read_json_file("./test/oli/resources/page.json")

      # all & only content elements carry id attributes w/unique values
      original_ids = extract_ids(content)

      {mapped_content, visited_id_count} =
        map_reduce_all_content(
          content,
          0,
          fn item, acc, _tr_context ->
            id = Map.get(item, "id")

            case id do
              nil -> {item, acc}
              id -> {Map.put(item, "id", "new" <> id), acc + 1}
            end
          end
        )

      # verify found all original ids
      assert visited_id_count == length(original_ids)

      # verify mapped all ids to "new"-prefixed ones
      new_ids = extract_ids(mapped_content)
      assert length(new_ids) == length(original_ids)
      assert Enum.all?(new_ids, &String.starts_with?(&1, "new"))
    end
  end
end
