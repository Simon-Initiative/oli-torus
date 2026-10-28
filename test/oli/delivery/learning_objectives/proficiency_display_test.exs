defmodule Oli.Delivery.LearningObjectives.ProficiencyDisplayTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.LearningObjectives.ProficiencyDisplay

  test "returns proficiency levels in display order" do
    assert ProficiencyDisplay.levels() == ["Not enough data", "Low", "Medium", "High"]
  end

  test "maps persisted proficiency values to student-facing display metadata" do
    assert %{label: "Beginning Proficiency", icon: :seed, level: :beginning} =
             ProficiencyDisplay.display_for("Low")

    assert %{label: "Growing Proficiency", icon: :sprout, level: :growing} =
             ProficiencyDisplay.display_for("Medium")

    assert %{label: "Strong Proficiency", icon: :tree, level: :strong} =
             ProficiencyDisplay.display_for("High")
  end

  test "falls back to not enough information display metadata" do
    assert %{
             label: "Not Enough Information",
             icon: :empty_pot,
             level: :not_enough_information,
             source_value: "unexpected"
           } = ProficiencyDisplay.display_for("unexpected")
  end
end
