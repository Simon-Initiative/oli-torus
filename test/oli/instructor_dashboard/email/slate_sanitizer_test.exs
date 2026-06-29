defmodule Oli.InstructorDashboard.Email.SlateSanitizerTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.Email.SlateSanitizer

  defp p(children), do: %{"type" => "p", "children" => children}

  describe "sanitize/1 — allowed content" do
    test "keeps paragraphs with text, preserving inline marks" do
      input = [p([%{"text" => "Hi ", "strong" => true}, %{"text" => "there"}])]
      assert SlateSanitizer.sanitize(input) == input
    end

    test "keeps a valid internal /course/link/:slug link, rebuilt to drop extra attrs" do
      input = [
        p([
          %{"text" => "see "},
          %{
            "type" => "a",
            "href" => "/course/link/intro",
            "onclick" => "evil()",
            "children" => [%{"text" => "Intro"}]
          }
        ])
      ]

      assert SlateSanitizer.sanitize(input) == [
               p([
                 %{"text" => "see "},
                 # onclick stripped; only type/href/children survive
                 %{
                   "type" => "a",
                   "href" => "/course/link/intro",
                   "children" => [%{"text" => "Intro"}]
                 }
               ])
             ]
    end
  end

  describe "sanitize/1 — dropped / neutralized content" do
    test "drops an unknown node type whose type string carries markup (the XSS vector)" do
      input = [
        p([%{"text" => "ok"}]),
        %{"type" => "<script>alert(1)</script>", "children" => [%{"text" => "x"}]}
      ]

      assert SlateSanitizer.sanitize(input) == [p([%{"text" => "ok"}])]
    end

    test "drops media nodes (img/iframe) with client-controlled src" do
      input = [
        %{"type" => "img", "src" => "javascript:alert(1)", "children" => [%{"text" => ""}]},
        %{"type" => "iframe", "src" => "https://evil.example", "children" => [%{"text" => ""}]},
        p([%{"text" => "body"}])
      ]

      assert SlateSanitizer.sanitize(input) == [p([%{"text" => "body"}])]
    end

    test "unwraps an off-allowlist (external) link but keeps its visible text" do
      input = [
        p([
          %{"type" => "a", "href" => "https://evil.example", "children" => [%{"text" => "click"}]}
        ])
      ]

      assert SlateSanitizer.sanitize(input) == [p([%{"text" => "click"}])]
    end

    test "drops non-paragraph block nodes" do
      input = [%{"type" => "h1", "children" => [%{"text" => "Heading"}]}, p([%{"text" => "ok"}])]
      assert SlateSanitizer.sanitize(input) == [p([%{"text" => "ok"}])]
    end

    test "returns an empty list for non-list / malformed input" do
      assert SlateSanitizer.sanitize(nil) == []
      assert SlateSanitizer.sanitize(%{"type" => "p"}) == []
      assert SlateSanitizer.sanitize("nope") == []
    end
  end
end
