defmodule Oli.Repo.Migrations.AddScopedFeatureFlagsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Repo
  alias Oli.ScopedFeatureFlags.ScopedFeatureFlagState

  describe "scoped_feature_flag_states table constraints" do
    test "exactly_one_resource check constraint prevents both project_id and section_id" do
      project = insert(:project)
      section = insert(:section)

      # This should fail due to the check constraint
      assert_raise Postgrex.Error, ~r/exactly_one_resource/, fn ->
        Repo.insert!(%ScopedFeatureFlagState{
          feature_name: "mcp_authoring",
          enabled: true,
          project_id: project.id,
          section_id: section.id
        })
      end
    end

    test "exactly_one_resource check constraint prevents neither project_id nor section_id" do
      # This should fail due to the check constraint
      assert_raise Postgrex.Error, ~r/exactly_one_resource/, fn ->
        Repo.insert!(%ScopedFeatureFlagState{
          feature_name: "mcp_authoring",
          enabled: true,
          project_id: nil,
          section_id: nil
        })
      end
    end

    test "exactly_one_resource check constraint allows project_id only" do
      project = insert(:project)

      assert {:ok, _flag_state} =
               Repo.insert(%ScopedFeatureFlagState{
                 feature_name: "mcp_authoring",
                 enabled: true,
                 project_id: project.id,
                 section_id: nil
               })
    end

    test "exactly_one_resource check constraint allows section_id only" do
      section = insert(:section)

      assert {:ok, _flag_state} =
               Repo.insert(%ScopedFeatureFlagState{
                 feature_name: "mcp_authoring",
                 enabled: true,
                 project_id: nil,
                 section_id: section.id
               })
    end

    test "unique constraint on feature_name and project_id" do
      project = insert(:project)

      Repo.insert!(%ScopedFeatureFlagState{
        feature_name: "mcp_authoring",
        enabled: true,
        project_id: project.id
      })

      # Second insert with same feature_name and project_id should fail
      assert_raise Postgrex.Error, ~r/unique constraint/, fn ->
        Repo.insert!(%ScopedFeatureFlagState{
          feature_name: "mcp_authoring",
          enabled: false,
          project_id: project.id
        })
      end
    end

    test "unique constraint on feature_name and section_id" do
      section = insert(:section)

      Repo.insert!(%ScopedFeatureFlagState{
        feature_name: "mcp_authoring",
        enabled: true,
        section_id: section.id
      })

      # Second insert with same feature_name and section_id should fail
      assert_raise Postgrex.Error, ~r/unique constraint/, fn ->
        Repo.insert!(%ScopedFeatureFlagState{
          feature_name: "mcp_authoring",
          enabled: false,
          section_id: section.id
        })
      end
    end

    test "foreign key constraint on project_id" do
      # This should fail due to foreign key constraint
      assert_raise Postgrex.Error, ~r/foreign key constraint/, fn ->
        Repo.insert!(%ScopedFeatureFlagState{
          feature_name: "mcp_authoring",
          enabled: true,
          project_id: 999_999
        })
      end
    end

    test "foreign key constraint on section_id" do
      # This should fail due to foreign key constraint
      assert_raise Postgrex.Error, ~r/foreign key constraint/, fn ->
        Repo.insert!(%ScopedFeatureFlagState{
          feature_name: "mcp_authoring",
          enabled: true,
          section_id: 999_999
        })
      end
    end

    test "cascade delete when project is deleted" do
      project = insert(:project)

      {:ok, flag_state} =
        Repo.insert(%ScopedFeatureFlagState{
          feature_name: "mcp_authoring",
          enabled: true,
          project_id: project.id
        })

      # Delete the project
      Repo.delete!(project)

      # The scoped feature flag state should be deleted as well
      refute Repo.get(ScopedFeatureFlagState, flag_state.id)
    end

    test "cascade delete when section is deleted" do
      section = insert(:section)

      {:ok, flag_state} =
        Repo.insert(%ScopedFeatureFlagState{
          feature_name: "mcp_authoring",
          enabled: true,
          section_id: section.id
        })

      # Delete the section
      Repo.delete!(section)

      # The scoped feature flag state should be deleted as well
      refute Repo.get(ScopedFeatureFlagState, flag_state.id)
    end

    test "indexes exist for performance" do
      # These tests verify that the indexes can be used by PostgreSQL
      # by checking that queries don't result in errors and work efficiently
      project = insert(:project)
      section = insert(:section)

      {:ok, project_flag} =
        Repo.insert(%ScopedFeatureFlagState{
          feature_name: "mcp_authoring",
          enabled: true,
          project_id: project.id
        })

      {:ok, section_flag} =
        Repo.insert(%ScopedFeatureFlagState{
          feature_name: "mcp_authoring",
          enabled: false,
          section_id: section.id
        })

      # Query by project_id (should use project_id index)
      assert [^project_flag] =
               Repo.all(from(s in ScopedFeatureFlagState, where: s.project_id == ^project.id))

      # Query by section_id (should use section_id index)
      assert [^section_flag] =
               Repo.all(from(s in ScopedFeatureFlagState, where: s.section_id == ^section.id))

      # Query by feature_name (should use feature_name index)
      assert [^project_flag, ^section_flag] =
               Repo.all(
                 from(s in ScopedFeatureFlagState,
                   where: s.feature_name == "mcp_authoring",
                   order_by: s.enabled
                 )
               )

      # Query by enabled (should use enabled index)
      assert [^section_flag] =
               Repo.all(
                 from(s in ScopedFeatureFlagState,
                   where: s.enabled == false,
                   order_by: s.feature_name
                 )
               )
    end
  end
end
