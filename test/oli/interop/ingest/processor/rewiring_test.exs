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

    test "drops activity references that cannot be rewritten" do
      unmapped_id = 999
      content = %{"type" => "activity-reference", "activity_id" => unmapped_id}
      map = %{}
      result = Rewiring.rewire_activity_references(content, map)
      assert is_nil(result)
    end

    test "removes unmapped activity references from nested content" do
      content = %{
        "model" => [
          %{"type" => "activity-reference", "activity_id" => 1},
          %{"type" => "activity-reference", "activity_id" => 2}
        ]
      }

      map = %{1 => 101}
      result = Rewiring.rewire_activity_references(content, map)

      [one_activity] = result["model"]
      assert one_activity["activity_id"] == 101
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
            "operator" => "all",
            "children" => [%{"fact" => "tags", "value" => [old_id1, old_id2], "operator" => "in"}]
          }
        }
      }

      tag_map = %{old_id1 => new_id1, old_id2 => new_id2}
      result = Rewiring.rewire_bank_selections(content, tag_map)
      [child] = result["logic"]["conditions"]["children"]
      assert Enum.sort(child["value"]) == Enum.sort([new_id1, new_id2])
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

  describe "rewire_bank_selections/2 with objectives" do
    test "rewires objective references in selection logic (expression)" do
      old_obj1 = 10
      old_obj2 = 11
      new_obj1 = 110
      new_obj2 = 111

      content = %{
        "type" => "selection",
        "logic" => %{
          "conditions" => %{
            "operator" => "all",
            "children" => [
              %{"fact" => "objectives", "operator" => "contains", "value" => [old_obj1, old_obj2]}
            ]
          }
        }
      }

      id_map = %{old_obj1 => new_obj1, old_obj2 => new_obj2}
      result = Rewiring.rewire_bank_selections(content, id_map)
      [child] = result["logic"]["conditions"]["children"]
      assert Enum.sort(child["value"]) == Enum.sort([new_obj1, new_obj2])
    end

    test "rewires objective references in nested clauses" do
      old_obj1 = 20
      old_obj2 = 21
      new_obj1 = 120
      new_obj2 = 121

      content = %{
        "type" => "selection",
        "logic" => %{
          "conditions" => %{
            "operator" => "any",
            "children" => [
              %{
                "operator" => "all",
                "children" => [
                  %{"fact" => "objectives", "operator" => "contains", "value" => [old_obj1]}
                ]
              },
              %{
                "operator" => "all",
                "children" => [
                  %{"fact" => "objectives", "operator" => "contains", "value" => [old_obj2]}
                ]
              }
            ]
          }
        }
      }

      id_map = %{old_obj1 => new_obj1, old_obj2 => new_obj2}
      result = Rewiring.rewire_bank_selections(content, id_map)
      [first_clause, second_clause] = result["logic"]["conditions"]["children"]
      [first_expr] = first_clause["children"]
      [second_expr] = second_clause["children"]

      assert first_expr["value"] == [new_obj1]
      assert second_expr["value"] == [new_obj2]
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

  describe "rewire_adaptive_link_references/2" do
    test "rewires adaptive tag a idref references" do
      content = %{
        "model" => [
          %{
            "type" => "content",
            "children" => [
              %{"tag" => "a", "idref" => "10", "children" => [%{"text" => "Go"}]},
              %{"tag" => "a", "href" => "https://example.org", "children" => [%{"text" => "Out"}]}
            ]
          }
        ]
      }

      result = Rewiring.rewire_adaptive_link_references(content, %{10 => 200})
      [container] = result["model"]
      [internal, external] = container["children"]

      assert internal["idref"] == 200
      assert external["href"] == "https://example.org"
    end

    test "is idempotent for already rewired adaptive idrefs" do
      content = %{
        "type" => "content",
        "children" => [
          %{"tag" => "a", "idref" => 200, "children" => [%{"text" => "Go"}]}
        ]
      }

      once = Rewiring.rewire_adaptive_link_references(content, %{200 => 200})
      twice = Rewiring.rewire_adaptive_link_references(once, %{200 => 200})

      assert once == twice
    end

    test "leaves unmapped adaptive idrefs unchanged" do
      content = %{
        "type" => "content",
        "children" => [
          %{"tag" => "a", "idref" => "missing", "children" => [%{"text" => "Go"}]}
        ]
      }

      result = Rewiring.rewire_adaptive_link_references(content, %{})
      [link] = result["children"]
      assert link["idref"] == "missing"
    end

    test "rewires adaptive iframe page-link idrefs" do
      content = %{
        "model" => [
          %{
            "type" => "content",
            "children" => [
              %{
                "type" => "janus-capi-iframe",
                "sourceType" => "page",
                "linkType" => "page",
                "idref" => "10",
                "src" => "/course/link/legacy"
              }
            ]
          }
        ]
      }

      result = Rewiring.rewire_adaptive_link_references(content, %{10 => 200})
      [container] = result["model"]
      [iframe] = container["children"]

      assert iframe["idref"] == 200
      assert iframe["resource_id"] == 200
      assert iframe["sourceType"] == "page"
      assert iframe["linkType"] == "page"
    end

    test "keeps adaptive iframe external URL mode unchanged" do
      content = %{
        "type" => "content",
        "children" => [
          %{
            "type" => "janus-capi-iframe",
            "sourceType" => "url",
            "linkType" => "page",
            "idref" => "10",
            "src" => "https://example.org/embed"
          }
        ]
      }

      result = Rewiring.rewire_adaptive_link_references(content, %{10 => 200})
      [iframe] = result["children"]

      assert iframe["sourceType"] == "url"
      assert iframe["idref"] == "10"
      refute Map.has_key?(iframe, "resource_id")
      assert iframe["src"] == "https://example.org/embed"
    end
  end
end
