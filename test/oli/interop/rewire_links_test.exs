defmodule Oli.Interop.RewireLinksTest do
  use ExUnit.Case, async: true
  alias Oli.Ingest.RewireLinks

  def fake_link_builder(id) do
    "rewritten:#{id}"
  end

  describe "rewire course internal page links" do
    test "lookup_revision/3 resolves by resource_id when page map is keyed by legacy id" do
      revision = %{resource_id: 200, slug: "page-two"}
      legacy_keyed_page_map = %{"10" => revision}
      resource_lookup = %{200 => revision, "200" => revision}

      assert RewireLinks.lookup_revision(legacy_keyed_page_map, resource_lookup, 200) == revision

      assert RewireLinks.lookup_revision(legacy_keyed_page_map, resource_lookup, "200") ==
               revision
    end

    test "lookup_revision/3 resolves mixed integer/string key forms" do
      revision = %{resource_id: 42, slug: "page-forty-two"}
      page_map = %{"42" => revision}
      resource_lookup = %{}

      assert RewireLinks.lookup_revision(page_map, resource_lookup, 42) == revision
      assert RewireLinks.lookup_revision(page_map, resource_lookup, "42") == revision
    end

    test "rewire/3 rewrites a link with an idref" do
      link = %{"type" => "a", "idref" => "id1", "children" => []}
      {true, rewritten} = RewireLinks.rewire(link, &fake_link_builder/1, %{})
      assert %{"type" => "a", "children" => [], "href" => "rewritten:id1"} == rewritten
    end

    test "rewire/3 does not rewrites a link with an href" do
      link = %{"type" => "a", "href" => "my-url", "children" => []}
      {false, rewritten} = RewireLinks.rewire(link, &fake_link_builder/1, %{})
      assert %{"type" => "a", "children" => [], "href" => "my-url"} == rewritten
    end

    test "rewire/3 maintains anchor and target attributes for href links" do
      link = %{
        "type" => "a",
        "href" => "my-url",
        "target" => "my-target",
        "anchor" => "my-anchor",
        "children" => []
      }

      {false, rewritten} = RewireLinks.rewire(link, &fake_link_builder/1, %{})

      assert %{
               "type" => "a",
               "children" => [],
               "href" => "my-url",
               "target" => "my-target",
               "anchor" => "my-anchor"
             } == rewritten
    end

    test "rewire/3 maintains anchor and target attributes for idref links" do
      link = %{
        "type" => "a",
        "idref" => "id1",
        "target" => "my-target",
        "anchor" => "my-anchor",
        "children" => []
      }

      {true, rewritten} = RewireLinks.rewire(link, &fake_link_builder/1, %{})

      assert %{
               "type" => "a",
               "children" => [],
               "href" => "rewritten:id1",
               "target" => "my-target",
               "anchor" => "my-anchor"
             } == rewritten
    end

    test "rewire/3 maintains anchor and not target attributes for idref links" do
      link = %{
        "type" => "a",
        "idref" => "id1",
        "anchor" => "my-anchor",
        "children" => []
      }

      {true, rewritten} = RewireLinks.rewire(link, &fake_link_builder/1, %{})

      assert %{
               "type" => "a",
               "children" => [],
               "href" => "rewritten:id1",
               "anchor" => "my-anchor"
             } == rewritten
    end

    test "rewire/3 rewrites a link in the children with an idref" do
      link = %{"type" => "a", "idref" => "id1", "children" => []}
      para = %{"type" => "p", "children" => [link]}
      {true, rewritten} = RewireLinks.rewire(para, &fake_link_builder/1, %{})

      assert %{
               "type" => "p",
               "children" => [%{"type" => "a", "children" => [], "href" => "rewritten:id1"}]
             } == rewritten
    end

    test "rewire/3 rewrites a link in a caption with an idref" do
      link = %{"type" => "a", "idref" => "id1", "children" => []}
      img = %{"type" => "img", "caption" => [link]}
      {true, rewritten} = RewireLinks.rewire(img, &fake_link_builder/1, %{})

      assert %{
               "type" => "img",
               "caption" => [%{"type" => "a", "children" => [], "href" => "rewritten:id1"}]
             } == rewritten
    end

    test "rewire/3 rewrites adaptive text node links with idref" do
      link = %{"tag" => "a", "idref" => "id1", "children" => [%{"text" => "My link"}]}
      {true, rewritten} = RewireLinks.rewire(link, &fake_link_builder/1, %{})

      assert %{
               "tag" => "a",
               "href" => "rewritten:id1",
               "children" => [%{"text" => "My link"}]
             } == rewritten

      refute Map.has_key?(rewritten, "idref")
    end

    test "rewire/3 rewrites nested adaptive internal links and leaves external links unchanged" do
      adaptive_nodes = %{
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "custom" => %{
                "nodes" => [
                  %{"tag" => "a", "idref" => "id1", "children" => [%{"text" => "Internal"}]},
                  %{
                    "tag" => "a",
                    "href" => "https://example.org",
                    "children" => [%{"text" => "External"}]
                  }
                ]
              }
            }
          ]
        },
        "stem" => []
      }

      {true, rewritten} = RewireLinks.rewire(adaptive_nodes, &fake_link_builder/1, %{})

      [part] = rewritten["authoring"]["parts"]
      [internal, external] = part["custom"]["nodes"]

      assert internal["href"] == "rewritten:id1"
      refute Map.has_key?(internal, "idref")
      assert external["href"] == "https://example.org"
    end

    test "rewire/3 rewrites adaptive links nested in part model payloads" do
      adaptive_nodes = %{
        "stem" => [],
        "authoring" => %{
          "parts" => [
            %{
              "id" => "part-1",
              "type" => "janus-text-flow",
              "model" => [
                %{
                  "tag" => "div",
                  "children" => [
                    %{"tag" => "a", "idref" => "id1", "children" => [%{"text" => "Internal"}]}
                  ]
                }
              ]
            }
          ]
        }
      }

      {true, rewritten} = RewireLinks.rewire(adaptive_nodes, &fake_link_builder/1, %{})

      [part] = rewritten["authoring"]["parts"]
      [container] = part["model"]
      [internal] = container["children"]

      assert internal["href"] == "rewritten:id1"
      refute Map.has_key?(internal, "idref")
    end

    test "rewire/3 rewrites adaptive links nested in partsLayout custom nodes" do
      adaptive_nodes = %{
        "content" => %{
          "partsLayout" => [
            %{
              "type" => "janus-text-flow",
              "custom" => %{
                "nodes" => [
                  %{
                    "tag" => "p",
                    "children" => [
                      %{
                        "tag" => "a",
                        "idref" => "5779",
                        "href" => "/course/link/quiz_1",
                        "children" => [%{"tag" => "text", "text" => "Lempp", "children" => []}]
                      }
                    ]
                  }
                ]
              }
            }
          ]
        }
      }

      {true, rewritten} = RewireLinks.rewire(adaptive_nodes, &fake_link_builder/1, %{})

      [part] = get_in(rewritten, ["content", "partsLayout"])
      [paragraph] = get_in(part, ["custom", "nodes"])
      [link] = paragraph["children"]

      assert link["href"] == "rewritten:5779"
      refute Map.has_key?(link, "idref")
    end
  end
end
