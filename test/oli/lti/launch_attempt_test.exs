defmodule Oli.Lti.LaunchAttemptTest do
  use Oli.DataCase

  alias Oli.Lti.LaunchAttempt

  import Oli.Factory

  describe "changeset/2" do
    test "validates required fields and terminal state requirements" do
      attrs =
        params_for(:lti_launch_attempt,
          lifecycle_state: :launch_failed,
          failure_classification: nil
        )

      changeset = LaunchAttempt.changeset(%LaunchAttempt{}, attrs)

      refute changeset.valid?
      assert %{failure_classification: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts a valid launch attempt" do
      changeset =
        LaunchAttempt.changeset(%LaunchAttempt{}, params_for(:lti_launch_attempt))

      assert changeset.valid?
    end
  end
end
