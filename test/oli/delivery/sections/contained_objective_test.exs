defmodule Oli.Delivery.Sections.ContainedObjectiveTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Sections.ContainedObjective

  describe "changeset/2" do
    test "changeset should be invalid if section_id is nil" do
      changeset =
        build(:contained_objective)
        |> ContainedObjective.changeset(%{section_id: nil})

      refute changeset.valid?
    end

    test "changeset should be invalid if container_id is nil" do
      changeset =
        build(:contained_objective)
        |> ContainedObjective.changeset(%{container_id: nil})

      refute changeset.valid?
    end
  end
end
