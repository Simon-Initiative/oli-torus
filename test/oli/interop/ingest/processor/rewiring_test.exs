defmodule Oli.Interop.Ingest.Processing.RewiringTest do
  use ExUnit.Case, async: true

  alias Oli.Interop.Ingest.Processing.Rewiring

  describe "rewire_activity_references/2" do
    test "rewires activity references" do
      old_id = 1
      new_id = 100
      content = %{"type" => "activity-reference", "activity_id" => old_id}
      map = %{old_id => new_id}
      result = Rewiring.rewire_activity_references(content, map)
      assert result["activity_id"] == new_id
    end

    test "always returns a map, even if mapping is missing" do
      unmapped_id = 999
      content = %{"type" => "activity-reference", "activity_id" => unmapped_id}
      map = %{}
      result = Rewiring.rewire_activity_references(content, map)
      assert is_map(result)
      assert result["activity_id"] == unmapped_id
    end
  end

  describe "rewire_report_activity_references/2" do
    test "rewires report activity references" do
      old_id = 2
      new_id = 200
      content = %{"type" => "report", "activityId" => old_id}
      map = %{old_id => new_id}
      result = Rewiring.rewire_report_activity_references(content, map)
      assert result["activityId"] == new_id
    end
  end

  describe "rewire_bank_selections/2" do
    test "rewires tag references in selection logic (children)" do
      old_id1 = 1
      old_id2 = 2
      new_id1 = 101
      new_id2 = 102

      content = %{
        "type" => "selection",
        "logic" => %{
          "conditions" => %{
            "children" => [%{"fact" => "tags", "value" => [old_id1, old_id2], "operator" => "in"}]
          }
        }
      }

      tag_map = %{old_id1 => new_id1, old_id2 => new_id2}
      result = Rewiring.rewire_bank_selections(content, tag_map)
      [child] = result["logic"]["conditions"]["children"]
      assert child["value"] == [new_id2, new_id1]
    end

    test "leaves unmapped tag references unchanged in selection logic (children)" do
      old_id = 3

      content = %{
        "type" => "selection",
        "logic" => %{
          "conditions" => %{
            "children" => [%{"fact" => "tags", "value" => [old_id], "operator" => "in"}]
          }
        }
      }

      tag_map = %{}
      result = Rewiring.rewire_bank_selections(content, tag_map)
      [child] = result["logic"]["conditions"]["children"]
      assert child["value"] == [old_id]
    end
  end

  describe "rewire_citation_references/2" do
    test "rewires bibrefs in content" do
      old_bib = "old_bib"
      new_bib = "new_bib"

      content = %{
        "bibrefs" => [old_bib],
        "type" => "content",
        "children" => [%{"type" => "cite", "bibref" => old_bib}]
      }

      bib_map = %{old_bib => %{resource_id: new_bib}}
      result = Rewiring.rewire_citation_references(content, bib_map)
      assert Enum.any?(result["bibrefs"], fn bib -> bib[:resource_id] == new_bib end)
      [child] = result["children"]
      assert child["bibref"] == %{resource_id: new_bib}
    end

    test "leaves unmapped bibrefs unchanged" do
      missing_bib = "missing_bib"

      content = %{
        "bibrefs" => [missing_bib],
        "type" => "content",
        "children" => [%{"type" => "cite", "bibref" => missing_bib}]
      }

      bib_map = %{}
      result = Rewiring.rewire_citation_references(content, bib_map)
      assert result["bibrefs"] == []
      [child] = result["children"]
      assert child["bibref"] == %{resource_id: missing_bib}
    end
  end

  describe "rewire_alternatives_groups/2" do
    test "rewires alternatives group references" do
      old_group = "old_group"
      new_group_id = "new_group_id"
      content = %{"type" => "alternatives", "group" => old_group}
      group_map = %{old_group => new_group_id}
      result = Rewiring.rewire_alternatives_groups(content, group_map)
      assert result["alternatives_id"] == new_group_id
    end

    test "leaves unmapped alternatives group references unchanged" do
      missing_group = "missing_group"
      content = %{"type" => "alternatives", "group" => missing_group}
      group_map = %{}
      result = Rewiring.rewire_alternatives_groups(content, group_map)
      assert result["group"] == missing_group
    end
  end
end
