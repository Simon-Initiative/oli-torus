defmodule OliWeb.Common.UtilsTest do
  use ExUnit.Case, async: true

  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.Utils

  import ExUnit.CaptureLog

  doctest Utils, import: true

  describe "extract_feedback_text/1" do
    test "extracts the feedback text from an attempt and logs an error if it can not be parsed" do
      activity_attempts = [
        %{
          part_attempts: [
            %{
              feedback: %{
                "content" => [
                  %{
                    "children" => [%{"text" => "First Feedback"}],
                    "id" => "7brHHbLfce3qYbdU8rkk23",
                    "type" => "p"
                  }
                ]
              }
            },
            %{
              feedback: %{
                "content" => [
                  %{
                    "children" => [%{"text" => "Second Feedback"}],
                    "id" => "7brHHbLfce3qYbdU8rkk23",
                    "type" => "p"
                  }
                ]
              }
            },
            %{
              feedback: %{
                "content" => %{
                  "model" => [
                    %{
                      "children" => [%{"text" => "Third Feedback"}],
                      "id" => "7brHHbLfce3qYbdU8rkk23",
                      "type" => "p"
                    }
                  ]
                }
              }
            },
            %{
              feedback: %{
                "content" => %{
                  "some_other_case" => [
                    %{
                      "children" => [
                        %{
                          "text" =>
                            "This feedback does not match any known case, so a Log error should be triggered"
                        }
                      ],
                      "id" => "7brHHbLfce3qYbdU8rkk23",
                      "type" => "p"
                    }
                  ]
                }
              }
            }
          ]
        }
      ]

      {result, log} =
        with_log(fn ->
          Utils.extract_feedback_text(activity_attempts)
        end)

      assert result == ["First Feedback", "Second Feedback", "Third Feedback"]

      assert log =~
               "[error] Could not parse feedback text from {\"some_other_case\", [%{\"children\" => [%{\"text\" => \"This feedback does not match any known case, so a Log error should be triggered\"}], \"id\" => \"7brHHbLfce3qYbdU8rkk23\", \"type\" => \"p\"}]}"
    end
  end
end
