defmodule Oli.FeatureGateTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.FeatureGate
  alias Oli.ScopedFeatureFlags.Rollouts

  describe "stage/3" do
    test "returns rollout stage for a project" do
      project = insert(:project)

      {:ok, _} =
        Rollouts.upsert_rollout(
          :canary_test_feature,
          :project,
          project.id,
          :five_percent,
          nil,
          []
        )

      assert FeatureGate.stage(project, :canary_test_feature) == "5"
    end

    test "prefers section assigns on conn" do
      project = insert(:project)
      section = insert(:section, base_project: project, publisher: project.publisher)

      {:ok, _} =
        Rollouts.upsert_rollout(
          :canary_test_feature,
          :section,
          section.id,
          :fifty_percent,
          nil,
          []
        )

      conn = %Plug.Conn{assigns: %{section: section, project: project}}

      assert FeatureGate.stage(conn, :canary_test_feature) == "50"
    end

    test "supports explicit resource option when assigns lack scope" do
      project = insert(:project)

      {:ok, _} =
        Rollouts.upsert_rollout(
          :canary_test_feature,
          :project,
          project.id,
          :internal_only,
          nil,
          []
        )

      conn = %Plug.Conn{assigns: %{}}

      assert FeatureGate.stage(conn, :canary_test_feature, resource: project) == "internal"
    end

    test "falls back to configured default when no stage is resolvable" do
      conn = %Plug.Conn{assigns: %{}}

      assert FeatureGate.stage(conn, :canary_test_feature, default_stage: "unknown") == "unknown"
    end
  end
end
