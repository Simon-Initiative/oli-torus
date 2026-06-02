defmodule Oli.Activities.AdaptivePartsTest do
  use ExUnit.Case, async: true

  alias Oli.Activities.AdaptiveParts

  test "defines the canonical adaptive scorable part types" do
    expected_types =
      MapSet.new([
        "janus-mcq",
        "janus-input-text",
        "janus-input-number",
        "janus-dropdown",
        "janus-slider",
        "janus-multi-line-text",
        "janus-hub-spoke",
        "janus-text-slider",
        "janus-fill-blanks"
      ])

    assert AdaptiveParts.scorable_part_types() == expected_types
  end

  test "does not treat display-only parts as scorable" do
    refute AdaptiveParts.scorable_part_type?("janus-formula")
    refute AdaptiveParts.scorable_part_type?("janus-popup")
    refute AdaptiveParts.scorable_part_type?("janus-text-flow")
  end

  test "separates analytics-tracked parts from persisted-only stateful parts" do
    content = %{
      "partsLayout" => [
        %{"id" => "janus_mcq-1", "type" => "janus-mcq"},
        %{"id" => "janus_capi_iframe-1", "type" => "janus-capi-iframe"},
        %{"id" => "janus_navigation_button-1", "type" => "janus-navigation-button"},
        %{"id" => "janus_formula-1", "type" => "janus-formula"}
      ],
      "authoring" => %{
        "parts" => [
          %{"id" => "janus_mcq-1", "type" => "janus-mcq", "gradingApproach" => "automatic"},
          %{
            "id" => "janus_capi_iframe-1",
            "type" => "janus-capi-iframe",
            "gradingApproach" => "manual"
          },
          %{"id" => "janus_navigation_button-1", "type" => "janus-navigation-button"},
          %{"id" => "janus_formula-1", "type" => "janus-formula"}
        ],
        "rules" => [
          %{
            "id" => "r.correct",
            "disabled" => false,
            "conditions" => %{
              "all" => [
                %{
                  "fact" => "stage.janus_capi_iframe-1.simScore",
                  "operator" => "equal",
                  "value" => "100"
                }
              ]
            }
          }
        ]
      }
    }

    assert AdaptiveParts.rule_scored_part_ids(content) ==
             MapSet.new(["janus_capi_iframe-1"])

    assert AdaptiveParts.tracked_part_ids(content) ==
             MapSet.new(["janus_mcq-1", "janus_capi_iframe-1"])

    assert AdaptiveParts.persisted_part_ids(content) ==
             MapSet.new(["janus_capi_iframe-1", "janus_mcq-1", "janus_navigation_button-1"])

    assert AdaptiveParts.rule_scored_part?(content, "janus_capi_iframe-1")
    assert AdaptiveParts.tracked_part?(content, "janus_capi_iframe-1")
    assert AdaptiveParts.tracked_part?(content, "janus_mcq-1")
    refute AdaptiveParts.tracked_part?(content, "janus_navigation_button-1")
    refute AdaptiveParts.tracked_part?(content, "janus_formula-1")

    assert AdaptiveParts.persisted_part?(content, "janus_navigation_button-1")

    assert AdaptiveParts.persisted_part_grading_approach(content, %{"id" => "janus_capi_iframe-1"}) ==
             :automatic
  end

  test "allows manually graded persisted stateful parts for manual grading" do
    content = %{
      "partsLayout" => [
        %{"id" => "janus_mcq-1", "type" => "janus-mcq"},
        %{"id" => "janus_capi_iframe-1", "type" => "janus-capi-iframe"},
        %{"id" => "janus_navigation_button-1", "type" => "janus-navigation-button"}
      ],
      "authoring" => %{
        "parts" => [
          %{"id" => "janus_mcq-1", "type" => "janus-mcq", "gradingApproach" => "automatic"},
          %{
            "id" => "janus_capi_iframe-1",
            "type" => "janus-capi-iframe",
            "gradingApproach" => "manual"
          },
          %{"id" => "janus_navigation_button-1", "type" => "janus-navigation-button"}
        ]
      }
    }

    assert AdaptiveParts.manual_gradeable_part_ids(content) ==
             MapSet.new(["janus_mcq-1", "janus_capi_iframe-1"])

    refute MapSet.member?(
             AdaptiveParts.manual_gradeable_part_ids(content),
             "janus_navigation_button-1"
           )
  end

  test "includes tracked and manually graded persisted parts in response summaries" do
    content = %{
      "partsLayout" => [
        %{"id" => "janus_mcq-1", "type" => "janus-mcq"},
        %{"id" => "janus_rule_capi-1", "type" => "janus-capi-iframe"},
        %{"id" => "janus_manual_capi-1", "type" => "janus-capi-iframe"},
        %{"id" => "janus_navigation_button-1", "type" => "janus-navigation-button"}
      ],
      "authoring" => %{
        "parts" => [
          %{"id" => "janus_mcq-1", "type" => "janus-mcq", "gradingApproach" => "automatic"},
          %{
            "id" => "janus_rule_capi-1",
            "type" => "janus-capi-iframe",
            "gradingApproach" => "automatic"
          },
          %{
            "id" => "janus_manual_capi-1",
            "type" => "janus-capi-iframe",
            "gradingApproach" => "manual"
          },
          %{"id" => "janus_navigation_button-1", "type" => "janus-navigation-button"}
        ],
        "rules" => [
          %{
            "id" => "r.correct",
            "disabled" => false,
            "conditions" => %{
              "all" => [
                %{
                  "fact" => "stage.janus_rule_capi-1.simScore",
                  "operator" => "equal",
                  "value" => "100"
                }
              ]
            }
          }
        ]
      }
    }

    assert AdaptiveParts.response_summary_part_ids(content) ==
             MapSet.new(["janus_mcq-1", "janus_rule_capi-1", "janus_manual_capi-1"])

    assert AdaptiveParts.response_summary_part?(content, "janus_manual_capi-1")
    refute AdaptiveParts.response_summary_part?(content, "janus_navigation_button-1")
  end

  test "prefers custom manual grading flags over stale authored gradingApproach metadata" do
    content = %{
      "partsLayout" => [
        %{
          "id" => "janus_multi_line_text-1",
          "type" => "janus-multi-line-text",
          "custom" => %{
            "requiresManualGrading" => true
          }
        }
      ],
      "authoring" => %{
        "parts" => [
          %{
            "id" => "janus_multi_line_text-1",
            "type" => "janus-multi-line-text",
            "gradingApproach" => "automatic"
          }
        ]
      }
    }

    assert AdaptiveParts.persisted_part_grading_approach(
             content,
             AdaptiveParts.part_definition(content, "janus_multi_line_text-1")
           ) == :manual
  end

  test "ignores missing ids when collecting persisted-only stateful parts" do
    content = %{
      "partsLayout" => [
        %{"id" => "janus_mcq-1", "type" => "janus-mcq"},
        %{"type" => "janus-navigation-button"}
      ],
      "authoring" => %{
        "parts" => [
          %{"id" => "janus_mcq-1", "type" => "janus-mcq", "gradingApproach" => "automatic"},
          %{"type" => "janus-navigation-button"}
        ]
      }
    }

    assert AdaptiveParts.persisted_part_ids(content) == MapSet.new(["janus_mcq-1"])
    refute MapSet.member?(AdaptiveParts.persisted_part_ids(content), nil)
  end
end
