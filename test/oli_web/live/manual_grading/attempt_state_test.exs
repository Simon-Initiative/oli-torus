defmodule OliWeb.ManualGrading.AttemptStateTest do
  use Oli.DataCase, async: true

  alias OliWeb.ManualGrading.AttemptState

  describe "parse_number/1" do
    test "a text of up to 308 bytes is converted whole; a longer one is never a number, even a finite one" do
      assert AttemptState.parse_number(String.duplicate("9", 308)) == 1.0e308
      assert AttemptState.parse_number(String.duplicate("9", 306) <> ".99") == nil
      assert AttemptState.parse_number(String.duplicate("9", 309)) == nil
    end
  end

  describe "out_of/2 for a manual part of an adaptive screen" do
    defp capi_out_of(screen_max_score) do
      attempt = %{
        activity_type_id: Oli.Activities.get_registration_by_slug("oli_adaptive").id,
        revision: %{
          content: %{
            "custom" => %{"maxScore" => screen_max_score},
            "partsLayout" => [%{"id" => "capi-1", "type" => "janus-capi-iframe"}],
            "authoring" => %{
              "parts" => [
                %{
                  "id" => "capi-1",
                  "type" => "janus-capi-iframe",
                  "gradingApproach" => "manual",
                  "outOf" => 2
                }
              ]
            }
          }
        }
      }

      parts_map =
        AttemptState.parts_map(attempt, [%{part_id: "capi-1", grading_approach: :manual}])

      AttemptState.out_of(%{part_id: "capi-1"}, parts_map)
    end

    test "an authored screen max score too long to be a float counts as none, never raising" do
      assert capi_out_of("4") == 4.0
      assert capi_out_of(String.duplicate("9", 309)) == 2
    end
  end
end
