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
end
