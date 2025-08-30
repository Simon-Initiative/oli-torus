defmodule Oli.Rendering.Activity.MarkdownTest do
  use Oli.DataCase

  alias Oli.Rendering.Context
  alias Oli.Rendering.Activity.Markdown

  describe "markdown activity renderer" do
    setup do
      author = author_fixture()
      %{author: author}
    end

    test "renders activity with nil activity_map gracefully", %{author: author} do
      element = %{
        "activity_id" => 1,
        "children" => [],
        "id" => 4_097_071_352,
        "purpose" => "none",
        "type" => "activity-reference"
      }

      # Test with nil activity_map - this should not crash
      rendered_markdown =
        Markdown.activity(
          %Context{user: author, activity_map: nil},
          element
        )

      # Should render placeholder text for the activity
      assert rendered_markdown == [
        "\n",
        "Question / Activity: 1",
        [],
        [],
        "\n\n"
      ]
    end

    test "renders activity with empty activity_map gracefully", %{author: author} do
      element = %{
        "activity_id" => 1,
        "children" => [],
        "id" => 4_097_071_352,
        "purpose" => "none",
        "type" => "activity-reference"
      }

      # Test with empty activity_map
      rendered_markdown =
        Markdown.activity(
          %Context{user: author, activity_map: %{}},
          element
        )

      # Should render placeholder text for the activity
      assert rendered_markdown == [
        "\n",
        "Question / Activity: 1",
        [],
        [],
        "\n\n"
      ]
    end

    test "renders activity with proper activity_map", %{author: author} do
      activity_map = %{
        1 => %{
          unencoded_model: %{
            "stem" => %{
              "content" => [%{"type" => "p", "children" => [%{"text" => "What is 2+2?"}]}]
            },
            "choices" => [
              %{"content" => [%{"type" => "p", "children" => [%{"text" => "3"}]}]},
              %{"content" => [%{"type" => "p", "children" => [%{"text" => "4"}]}]}
            ]
          }
        }
      }

      element = %{
        "activity_id" => 1,
        "children" => [],
        "id" => 4_097_071_352,
        "purpose" => "none",
        "type" => "activity-reference"
      }

      rendered_markdown =
        Markdown.activity(
          %Context{user: author, activity_map: activity_map},
          element
        )

      # Should render the activity with question and choices
      [newline1, title, stem_content, choices_content, newline2] = rendered_markdown

      assert newline1 == "\n"
      assert title == "Question / Activity: 1"
      assert newline2 == "\n\n"
      # stem_content and choices_content are rendered by the content renderer
      # so we just verify they exist
      assert is_list(stem_content)
      assert is_list(choices_content)
    end
  end
end