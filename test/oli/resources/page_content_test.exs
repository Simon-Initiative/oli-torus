defmodule Oli.Resources.PageContentTest do
  use ExUnit.Case, async: true

  alias Oli.Resources.PageContent

  @content %{
    "model" => [
      %{
        "type" => "group",
        "layout" => "deck",
        "children" => [
          %{
            "type" => "group",
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
      assert {_, 8} = PageContent.map_reduce(@content, 0, fn item, acc -> {item, acc + 1} end)
    end
  end

  describe "map support via map_reduce" do
    test "it numbers all the nodes" do
      {item, _} =
        PageContent.map_reduce(@content, 0, fn item, acc ->
          {Map.put(item, "id", acc + 1), acc + 1}
        end)

      activity4 = item["model"] |> Enum.at(0) |> Map.get("children") |> Enum.at(1)
      assert activity4["id"] == 5
    end
  end

  describe "flat filter support" do
    test "it flattens and filters all activity references" do
      refs =
        PageContent.flat_filter(@content, fn item ->
          Map.get(item, "type") == "activity-reference"
        end)

      assert length(refs) == 5
      assert Enum.all?(refs, fn a -> Map.get(a, "type") == "activity-reference" end)
      assert 15 = Enum.reduce(refs, 0, fn %{"activity_id" => id}, total -> total + id end)
    end
  end

  describe "map support via map" do
    test "it adds" do
      item = PageContent.map(@content, fn item -> Map.put(item, "id", 1) end)

      activity4 = item["model"] |> Enum.at(0) |> Map.get("children") |> Enum.at(1)
      assert activity4["id"] == 1
    end
  end
end
