defmodule Oli.ScopedFeatureFlags.ScopedFeatureRolloutTest do
  use Oli.DataCase, async: true

  alias Oli.ScopedFeatureFlags.ScopedFeatureRollout

  describe "changeset/2" do
    test "is valid with required fields for project scope" do
      params = %{
        feature_name: "mcp_authoring",
        scope_type: :project,
        scope_id: 123,
        stage: :internal_only,
        rollout_percentage: 0
      }

      changeset = ScopedFeatureRollout.changeset(%ScopedFeatureRollout{}, params)

      assert changeset.valid?
    end

    test "normalizes scope_id for global scope" do
      params = %{
        feature_name: "mcp_authoring",
        scope_type: :global,
        scope_id: 10,
        stage: :full,
        rollout_percentage: 100
      }

      changeset = ScopedFeatureRollout.changeset(%ScopedFeatureRollout{}, params)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :scope_id) == nil
    end

    test "requires scope_id for project and section scopes" do
      params = %{
        feature_name: "mcp_authoring",
        scope_type: :project,
        stage: :five_percent,
        rollout_percentage: 5
      }

      changeset = ScopedFeatureRollout.changeset(%ScopedFeatureRollout{}, params)

      refute changeset.valid?
      assert {"must be present for project scope", _} = changeset.errors[:scope_id]
    end

    test "rejects invalid rollout percentage" do
      params = %{
        feature_name: "mcp_authoring",
        scope_type: :section,
        scope_id: 321,
        stage: :five_percent,
        rollout_percentage: 101
      }

      changeset = ScopedFeatureRollout.changeset(%ScopedFeatureRollout{}, params)

      refute changeset.valid?

      assert {"must be less than or equal to %{number}", _} =
               changeset.errors[:rollout_percentage]
    end
  end
end
