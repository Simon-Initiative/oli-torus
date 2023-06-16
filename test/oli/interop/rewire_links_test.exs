defmodule Oli.Interop.RewireLinksTest do
  use ExUnit.Case, async: true
  alias Oli.Ingest.RewireLinks

  def fake_link_builder(id) do
    "rewritten:#{id}"
  end

  describe "rewire course internal page links" do
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
  end
end
