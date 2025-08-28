defmodule Oli.ScopedFeatureFlagsTest do
  use Oli.DataCase

  alias Oli.ScopedFeatureFlags
  alias Oli.ScopedFeatureFlags.ScopedFeatureFlagState

  import Oli.Factory

  describe "enabled?/2" do
    test "returns false for non-existent feature flag for project" do
      project = insert(:project)
      refute ScopedFeatureFlags.enabled?("mcp_authoring", project)
    end

    test "returns false for non-existent feature flag for section" do
      section = insert(:section)
      refute ScopedFeatureFlags.enabled?("mcp_authoring", section)
    end

    test "returns true for enabled feature flag for project" do
      project = insert(:project)
      {:ok, _} = ScopedFeatureFlags.enable_feature("mcp_authoring", project)
      assert ScopedFeatureFlags.enabled?("mcp_authoring", project)
    end

    test "returns false for disabled feature flag for project" do
      project = insert(:project)
      {:ok, _} = ScopedFeatureFlags.disable_feature("mcp_authoring", project)
      refute ScopedFeatureFlags.enabled?("mcp_authoring", project)
    end

    test "returns true for enabled feature flag for section" do
      section = insert(:section)
      {:ok, _} = ScopedFeatureFlags.enable_feature("mcp_authoring", section)
      assert ScopedFeatureFlags.enabled?("mcp_authoring", section)
    end

    test "returns false for disabled feature flag for section" do
      section = insert(:section)
      {:ok, _} = ScopedFeatureFlags.disable_feature("mcp_authoring", section)
      refute ScopedFeatureFlags.enabled?("mcp_authoring", section)
    end
  end

  describe "enable_feature/2 and disable_feature/2" do
    test "enables and disables feature for project" do
      project = insert(:project)
      
      # Enable
      {:ok, flag_state} = ScopedFeatureFlags.enable_feature("mcp_authoring", project)
      assert flag_state.enabled
      assert flag_state.feature_name == "mcp_authoring"
      assert flag_state.project_id == project.id
      refute flag_state.section_id

      # Check enabled
      assert ScopedFeatureFlags.enabled?("mcp_authoring", project)

      # Disable  
      {:ok, flag_state} = ScopedFeatureFlags.disable_feature("mcp_authoring", project)
      refute flag_state.enabled
      assert flag_state.feature_name == "mcp_authoring"
      assert flag_state.project_id == project.id
      refute flag_state.section_id

      # Check disabled
      refute ScopedFeatureFlags.enabled?("mcp_authoring", project)
    end

    test "enables and disables feature for section" do
      section = insert(:section)
      
      # Enable
      {:ok, flag_state} = ScopedFeatureFlags.enable_feature("mcp_authoring", section)
      assert flag_state.enabled
      assert flag_state.feature_name == "mcp_authoring"
      assert flag_state.section_id == section.id
      refute flag_state.project_id

      # Check enabled
      assert ScopedFeatureFlags.enabled?("mcp_authoring", section)

      # Disable
      {:ok, flag_state} = ScopedFeatureFlags.disable_feature("mcp_authoring", section)
      refute flag_state.enabled
      assert flag_state.feature_name == "mcp_authoring"
      assert flag_state.section_id == section.id
      refute flag_state.project_id

      # Check disabled
      refute ScopedFeatureFlags.enabled?("mcp_authoring", section)
    end

    test "idempotent operations for project" do
      project = insert(:project)
      
      # Enable twice
      {:ok, flag1} = ScopedFeatureFlags.enable_feature("mcp_authoring", project)
      {:ok, flag2} = ScopedFeatureFlags.enable_feature("mcp_authoring", project)
      
      assert flag1.id == flag2.id
      assert flag1.enabled == flag2.enabled == true

      # Disable twice
      {:ok, flag3} = ScopedFeatureFlags.disable_feature("mcp_authoring", project)
      {:ok, flag4} = ScopedFeatureFlags.disable_feature("mcp_authoring", project)
      
      assert flag3.id == flag4.id == flag1.id
      assert flag3.enabled == flag4.enabled == false
    end

    test "idempotent operations for section" do
      section = insert(:section)
      
      # Enable twice
      {:ok, flag1} = ScopedFeatureFlags.enable_feature("mcp_authoring", section)
      {:ok, flag2} = ScopedFeatureFlags.enable_feature("mcp_authoring", section)
      
      assert flag1.id == flag2.id
      assert flag1.enabled == flag2.enabled == true

      # Disable twice
      {:ok, flag3} = ScopedFeatureFlags.disable_feature("mcp_authoring", section)
      {:ok, flag4} = ScopedFeatureFlags.disable_feature("mcp_authoring", section)
      
      assert flag3.id == flag4.id == flag1.id
      assert flag3.enabled == flag4.enabled == false
    end
  end

  describe "list_project_features/1" do
    test "returns empty list for project with no features" do
      project = insert(:project)
      assert ScopedFeatureFlags.list_project_features(project) == []
    end

    test "returns feature flags for project ordered by feature_name" do
      project = insert(:project)
      
      {:ok, _} = ScopedFeatureFlags.enable_feature("z_feature", project)
      {:ok, _} = ScopedFeatureFlags.enable_feature("a_feature", project) 
      {:ok, _} = ScopedFeatureFlags.disable_feature("m_feature", project)

      features = ScopedFeatureFlags.list_project_features(project)
      feature_names = Enum.map(features, & &1.feature_name)
      
      assert feature_names == ["a_feature", "m_feature", "z_feature"]
    end
  end

  describe "list_section_features/1" do
    test "returns empty list for section with no features" do
      section = insert(:section)
      assert ScopedFeatureFlags.list_section_features(section) == []
    end

    test "returns feature flags for section ordered by feature_name" do
      section = insert(:section)
      
      {:ok, _} = ScopedFeatureFlags.enable_feature("z_feature", section)
      {:ok, _} = ScopedFeatureFlags.enable_feature("a_feature", section)
      {:ok, _} = ScopedFeatureFlags.disable_feature("m_feature", section)

      features = ScopedFeatureFlags.list_section_features(section)
      feature_names = Enum.map(features, & &1.feature_name)
      
      assert feature_names == ["a_feature", "m_feature", "z_feature"]
    end
  end

  describe "list_all_features/0" do
    test "returns all feature flags across projects and sections" do
      project = insert(:project)
      section = insert(:section)
      
      {:ok, _} = ScopedFeatureFlags.enable_feature("mcp_authoring", project)
      {:ok, _} = ScopedFeatureFlags.enable_feature("mcp_authoring", section)
      {:ok, _} = ScopedFeatureFlags.disable_feature("other_feature", project)

      features = ScopedFeatureFlags.list_all_features()
      
      assert length(features) == 3
      assert Enum.all?(features, fn f -> f.project || f.section end)
      
      feature_names = Enum.map(features, & &1.feature_name)
      assert "mcp_authoring" in feature_names
      assert "other_feature" in feature_names
    end
  end

  describe "remove_feature/2" do
    test "removes feature flag for project" do
      project = insert(:project)
      
      {:ok, _} = ScopedFeatureFlags.enable_feature("mcp_authoring", project)
      assert ScopedFeatureFlags.enabled?("mcp_authoring", project)
      
      {:ok, _} = ScopedFeatureFlags.remove_feature("mcp_authoring", project)
      refute ScopedFeatureFlags.enabled?("mcp_authoring", project)
    end

    test "removes feature flag for section" do
      section = insert(:section)
      
      {:ok, _} = ScopedFeatureFlags.enable_feature("mcp_authoring", section)
      assert ScopedFeatureFlags.enabled?("mcp_authoring", section)
      
      {:ok, _} = ScopedFeatureFlags.remove_feature("mcp_authoring", section)
      refute ScopedFeatureFlags.enabled?("mcp_authoring", section)
    end

    test "returns error for non-existent feature flag for project" do
      project = insert(:project)
      assert {:error, :not_found} = ScopedFeatureFlags.remove_feature("mcp_authoring", project)
    end

    test "returns error for non-existent feature flag for section" do
      section = insert(:section)  
      assert {:error, :not_found} = ScopedFeatureFlags.remove_feature("mcp_authoring", section)
    end
  end

  describe "resource isolation" do
    test "project and section feature flags are independent" do
      project = insert(:project)
      section = insert(:section)
      
      # Enable for project only
      {:ok, _} = ScopedFeatureFlags.enable_feature("mcp_authoring", project)
      
      assert ScopedFeatureFlags.enabled?("mcp_authoring", project)
      refute ScopedFeatureFlags.enabled?("mcp_authoring", section)
      
      # Enable for section only
      {:ok, _} = ScopedFeatureFlags.enable_feature("mcp_authoring", section)
      
      assert ScopedFeatureFlags.enabled?("mcp_authoring", project)
      assert ScopedFeatureFlags.enabled?("mcp_authoring", section)
      
      # Disable project feature
      {:ok, _} = ScopedFeatureFlags.disable_feature("mcp_authoring", project)
      
      refute ScopedFeatureFlags.enabled?("mcp_authoring", project)
      assert ScopedFeatureFlags.enabled?("mcp_authoring", section)
    end
  end
end