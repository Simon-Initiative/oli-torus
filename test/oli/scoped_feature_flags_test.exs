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

  describe "batch operations" do
    test "batch_enabled?/2 returns correct map for projects" do
      project = insert(:project)
      
      {:ok, _} = ScopedFeatureFlags.enable_feature("feature1", project)
      {:ok, _} = ScopedFeatureFlags.disable_feature("feature2", project)
      
      result = ScopedFeatureFlags.batch_enabled?(["feature1", "feature2", "feature3"], project)
      
      assert result == %{
        "feature1" => true,
        "feature2" => false,
        "feature3" => false
      }
    end

    test "batch_enabled?/2 returns correct map for sections" do
      section = insert(:section)
      
      {:ok, _} = ScopedFeatureFlags.enable_feature("feature1", section)
      {:ok, _} = ScopedFeatureFlags.disable_feature("feature2", section)
      
      result = ScopedFeatureFlags.batch_enabled?(["feature1", "feature2", "feature3"], section)
      
      assert result == %{
        "feature1" => true,
        "feature2" => false,
        "feature3" => false
      }
    end

    test "batch_enabled_projects?/2 returns correct map" do
      project1 = insert(:project)
      project2 = insert(:project)
      project3 = insert(:project)
      
      {:ok, _} = ScopedFeatureFlags.enable_feature("mcp_authoring", project1)
      {:ok, _} = ScopedFeatureFlags.disable_feature("mcp_authoring", project2)
      
      result = ScopedFeatureFlags.batch_enabled_projects?("mcp_authoring", [project1.id, project2.id, project3.id])
      
      assert result == %{
        project1.id => true,
        project2.id => false,
        project3.id => false
      }
    end

    test "set_features_atomically/2 succeeds when all operations are valid for project" do
      project = insert(:project)
      
      feature_settings = [
        {"feature1", true},
        {"feature2", false},
        {"feature3", true}
      ]
      
      {:ok, results} = ScopedFeatureFlags.set_features_atomically(feature_settings, project)
      
      assert length(results) == 3
      assert ScopedFeatureFlags.enabled?("feature1", project)
      refute ScopedFeatureFlags.enabled?("feature2", project)
      assert ScopedFeatureFlags.enabled?("feature3", project)
    end

    test "set_features_atomically/2 rolls back all operations on failure for project" do
      project = insert(:project)
      
      feature_settings = [
        {"valid_feature", true},
        {"", false}, # This should cause validation failure
        {"another_feature", true}
      ]
      
      {:error, _} = ScopedFeatureFlags.set_features_atomically(feature_settings, project)
      
      # None of the features should be set due to rollback
      refute ScopedFeatureFlags.enabled?("valid_feature", project)
      refute ScopedFeatureFlags.enabled?("another_feature", project)
    end
  end

  describe "input validation" do
    test "rejects invalid feature names" do
      project = insert(:project)

      # Empty string
      {:error, errors} = ScopedFeatureFlags.enable_feature("", project)
      assert "Feature name cannot be empty" in errors[:invalid_feature_name]

      # Too long
      long_name = String.duplicate("a", 256)
      {:error, errors} = ScopedFeatureFlags.enable_feature(long_name, project)
      assert "Feature name cannot be longer than 255 characters" in errors[:invalid_feature_name]

      # Invalid characters
      {:error, errors} = ScopedFeatureFlags.enable_feature("feature name with spaces", project)
      assert "Feature name can only contain letters, numbers, underscores, hyphens, and periods" in errors[:invalid_feature_name]

      # Non-string
      {:error, errors} = ScopedFeatureFlags.enable_feature(:atom_name, project)
      assert "Feature name must be a string" in errors[:invalid_feature_name]
    end

    test "accepts valid feature names" do
      project = insert(:project)

      valid_names = [
        "feature_name",
        "feature-name",
        "feature.name",
        "feature123",
        "Feature_Name-123.test"
      ]

      Enum.each(valid_names, fn name ->
        {:ok, _} = ScopedFeatureFlags.enable_feature(name, project)
        assert ScopedFeatureFlags.enabled?(name, project)
      end)
    end
  end

  describe "property-based behavior tests" do
    @tag timeout: 30_000
    test "idempotency property: enable/disable operations are idempotent" do
      project = insert(:project)
      feature_name = "test_feature"
      
      # Test multiple enables
      Enum.each(1..10, fn _ ->
        {:ok, flag_state} = ScopedFeatureFlags.enable_feature(feature_name, project)
        assert flag_state.enabled == true
        assert ScopedFeatureFlags.enabled?(feature_name, project)
      end)
      
      # Test multiple disables
      Enum.each(1..10, fn _ ->
        {:ok, flag_state} = ScopedFeatureFlags.disable_feature(feature_name, project)
        assert flag_state.enabled == false
        refute ScopedFeatureFlags.enabled?(feature_name, project)
      end)
    end
    
    @tag timeout: 30_000
    test "state transition property: enable -> disable -> enable produces consistent results" do
      projects = insert_list(5, :project)
      sections = insert_list(5, :section)
      feature_names = ["feature1", "feature2", "feature3"]
      
      all_resources = projects ++ sections
      
      Enum.each(all_resources, fn resource ->
        Enum.each(feature_names, fn feature_name ->
          # Initial state should be false
          refute ScopedFeatureFlags.enabled?(feature_name, resource)
          
          # Enable
          {:ok, _} = ScopedFeatureFlags.enable_feature(feature_name, resource)
          assert ScopedFeatureFlags.enabled?(feature_name, resource)
          
          # Disable
          {:ok, _} = ScopedFeatureFlags.disable_feature(feature_name, resource)
          refute ScopedFeatureFlags.enabled?(feature_name, resource)
          
          # Enable again
          {:ok, _} = ScopedFeatureFlags.enable_feature(feature_name, resource)
          assert ScopedFeatureFlags.enabled?(feature_name, resource)
          
          # Final disable
          {:ok, _} = ScopedFeatureFlags.disable_feature(feature_name, resource)
          refute ScopedFeatureFlags.enabled?(feature_name, resource)
        end)
      end)
    end

    test "isolation property: operations on different resources don't interfere" do
      project1 = insert(:project)
      project2 = insert(:project)
      section1 = insert(:section)
      section2 = insert(:section)
      
      feature_name = "test_feature"
      
      # Enable for project1 only
      {:ok, _} = ScopedFeatureFlags.enable_feature(feature_name, project1)
      
      # Verify isolation
      assert ScopedFeatureFlags.enabled?(feature_name, project1)
      refute ScopedFeatureFlags.enabled?(feature_name, project2)
      refute ScopedFeatureFlags.enabled?(feature_name, section1)
      refute ScopedFeatureFlags.enabled?(feature_name, section2)
      
      # Enable for section2
      {:ok, _} = ScopedFeatureFlags.enable_feature(feature_name, section2)
      
      # Verify continued isolation
      assert ScopedFeatureFlags.enabled?(feature_name, project1)
      refute ScopedFeatureFlags.enabled?(feature_name, project2)
      refute ScopedFeatureFlags.enabled?(feature_name, section1)
      assert ScopedFeatureFlags.enabled?(feature_name, section2)
      
      # Disable project1
      {:ok, _} = ScopedFeatureFlags.disable_feature(feature_name, project1)
      
      # Verify section2 unaffected
      refute ScopedFeatureFlags.enabled?(feature_name, project1)
      refute ScopedFeatureFlags.enabled?(feature_name, project2)
      refute ScopedFeatureFlags.enabled?(feature_name, section1)
      assert ScopedFeatureFlags.enabled?(feature_name, section2)
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