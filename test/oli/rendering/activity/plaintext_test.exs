defmodule Oli.Rendering.Activity.PlaintextTest do
  use Oli.DataCase

  alias Oli.Rendering.Activity
  alias Oli.Rendering.Activity.ActivitySummary
  alias Oli.Rendering.Context

  import ExUnit.CaptureLog

  describe "plaintext activity renderer" do
    setup do
      %{author: author_fixture()}
    end

    test "uses preview elements for instructor preview when preview metadata is present", %{
      author: author
    } do
      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{}",
          model: "{}",
          delivery_element: "oli-multiple-choice-delivery",
          authoring_element: "oli-multiple-choice-authoring",
          preview_element: "oli-multiple-choice-preview",
          preview_script: "oli_multiple_choice_preview.js",
          activity_type_slug: "oli_multiple_choice",
          script: "oli_multiple_choice_preview.js",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      rendered =
        Activity.render(
          %Context{user: author, activity_map: activity_map, mode: :instructor_preview},
          %{"activity_id" => 1},
          Activity.Plaintext
        )

      assert rendered == ["[Activity 'oli-multiple-choice-preview']"]
    end

    test "logs and falls back to authoring elements for supported preview types without preview metadata",
         %{author: author} do
      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{}",
          model: "{}",
          delivery_element: "oli-multiple-choice-delivery",
          authoring_element: "oli-multiple-choice-authoring",
          activity_type_slug: "oli_multiple_choice",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      assert capture_log(fn ->
               rendered =
                 Activity.render(
                   %Context{user: author, activity_map: activity_map, mode: :instructor_preview},
                   %{"activity_id" => 1},
                   Activity.Plaintext
                 )

               assert rendered == ["[Activity 'oli-multiple-choice-authoring']"]
             end) =~
               "Instructor preview plaintext fallback to authoring element for supported activity type oli_multiple_choice"
    end
  end
end
