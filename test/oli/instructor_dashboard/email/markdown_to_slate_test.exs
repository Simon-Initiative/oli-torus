defmodule Oli.InstructorDashboard.Email.MarkdownToSlateTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.Email.MarkdownToSlate

  describe "to_slate/1" do
    test "converts an inline markdown link into a Slate link node surrounded by text" do
      [%{"type" => "p", "children" => children}] =
        MarkdownToSlate.to_slate("Visit [Lesson 1](/course/link/lesson-1) today.")

      link = Enum.find(children, &(&1["type"] == "a"))
      assert link["href"] == "/course/link/lesson-1"
      assert link["children"] == [%{"text" => "Lesson 1"}]

      # The link is surrounded by the literal text, not flattened into it.
      text = children |> Enum.map(& &1["text"]) |> Enum.join()
      assert text =~ "Visit"
      assert text =~ "today."
      refute Enum.any?(children, fn node -> (node["text"] || "") =~ "[Lesson 1]" end)
    end

    test "keeps a plain paragraph as a single text node" do
      assert MarkdownToSlate.to_slate("Hello world.") ==
               [%{"type" => "p", "children" => [%{"text" => "Hello world."}]}]
    end

    test "preserves multiple paragraphs" do
      nodes = MarkdownToSlate.to_slate("First paragraph.\n\nSecond paragraph.")

      assert length(nodes) == 2
      assert Enum.all?(nodes, &(&1["type"] == "p"))
    end

    test "flattens a numbered list into paragraphs (no list block types)" do
      nodes = MarkdownToSlate.to_slate("To do:\n\n1. First item\n2. Second item")

      types = Enum.map(nodes, & &1["type"]) |> Enum.uniq()
      assert types == ["p"]

      text =
        nodes
        |> Enum.flat_map(& &1["children"])
        |> Enum.map(&(&1["text"] || ""))
        |> Enum.join(" ")

      assert text =~ "First item"
      assert text =~ "Second item"
    end

    test "preserves inline marks like bold" do
      [%{"type" => "p", "children" => children}] =
        MarkdownToSlate.to_slate("This is **bold** text.")

      assert Enum.any?(children, &(&1["text"] == "bold" and &1["strong"] == true))
    end

    test "drops unsafe link targets but keeps the link text" do
      [%{"type" => "p", "children" => children}] =
        MarkdownToSlate.to_slate("See [Bad](https://evil.com) here.")

      refute Enum.any?(children, &(&1["type"] == "a"))
      text = children |> Enum.map(&(&1["text"] || "")) |> Enum.join()
      assert text =~ "See"
      assert text =~ "Bad"
    end

    test "keeps safe internal links as link nodes" do
      [%{"type" => "p", "children" => children}] =
        MarkdownToSlate.to_slate("See [Good](/course/link/lesson-1) here.")

      link = Enum.find(children, &(&1["type"] == "a"))
      assert link["href"] == "/course/link/lesson-1"
    end

    test "returns an empty paragraph for empty input" do
      assert MarkdownToSlate.to_slate("") == [%{"type" => "p", "children" => [%{"text" => ""}]}]
      assert MarkdownToSlate.to_slate(nil) == [%{"type" => "p", "children" => [%{"text" => ""}]}]
    end
  end
end
