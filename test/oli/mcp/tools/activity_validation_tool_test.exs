defmodule Oli.MCP.Tools.ActivityValidationToolTest do
  use ExUnit.Case, async: true

  alias Oli.MCP.Tools.ActivityValidationTool

  describe "activity validation tool" do
    test "validates valid activity JSON" do
      valid_activity = %{
        "stem" => %{
          "content" => [%{"type" => "p", "children" => [%{"text" => "Question text"}]}],
          "editor" => "slate",
          "id" => "123",
          "textDirection" => "ltr"
        },
        "choices" => [
          %{
            "content" => [%{"type" => "p", "children" => [%{"text" => "Choice A"}]}],
            "editor" => "slate",
            "id" => "456",
            "textDirection" => "ltr"
          }
        ],
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "hints" => [],
              "responses" => [
                %{
                  "id" => "response1",
                  "rule" => "input like {456}",
                  "score" => 1,
                  "correct" => true,
                  "feedback" => %{
                    "content" => [%{"type" => "p", "children" => [%{"text" => "Correct"}]}],
                    "editor" => "slate",
                    "id" => "feedback1",
                    "textDirection" => "ltr"
                  }
                }
              ],
              "gradingApproach" => "automatic",
              "scoringStrategy" => "average",
              "targets" => []
            }
          ],
          "previewText" => "Question text",
          "targeted" => [],
          "transformations" => [],
          "version" => 2
        }
      }

      json_string = Jason.encode!(valid_activity)

      frame = %{}
      result = ActivityValidationTool.execute(%{activity_json: json_string}, frame)

      assert {:reply, response, ^frame} = result
      assert response.content == [%{"type" => "text", "text" => "Activity JSON is valid"}]
    end

    test "returns error for invalid JSON" do
      invalid_json = "{ invalid json"

      frame = %{}
      result = ActivityValidationTool.execute(%{activity_json: invalid_json}, frame)

      assert {:reply, response, ^frame} = result
      assert response.isError == true
      assert [%{"type" => "text", "text" => error_text}] = response.content
      assert String.contains?(error_text, "Invalid JSON")
    end

    test "returns error for activity that fails validation" do
      # Activity with invalid content structure that should fail content validation
      invalid_activity = %{
        "stem" => %{
          "content" => [%{"type" => "invalid_type", "children" => "not_an_array"}],
          "editor" => "slate",
          "id" => "123",
          "textDirection" => "ltr"
        }
      }

      json_string = Jason.encode!(invalid_activity)

      frame = %{}
      result = ActivityValidationTool.execute(%{activity_json: json_string}, frame)

      assert {:reply, response, ^frame} = result
      assert response.isError == true
      assert [%{"type" => "text", "text" => error_text}] = response.content
      assert String.contains?(error_text, "Validation failed")
    end
  end
end
