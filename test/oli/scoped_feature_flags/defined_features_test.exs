defmodule Oli.ScopedFeatureFlags.DefinedFeaturesTest do
  use ExUnit.Case

  alias Oli.ScopedFeatureFlags.DefinedFeatures

  describe "defined features" do
    test "mcp_authoring feature is properly defined" do
      assert DefinedFeatures.valid_feature?(:mcp_authoring)
      assert DefinedFeatures.valid_feature?("mcp_authoring")

      feature = DefinedFeatures.get_feature(:mcp_authoring)
      assert feature.name == :mcp_authoring
      assert feature.scopes == [:authoring]
      assert feature.string_name == "mcp_authoring"
      assert String.contains?(feature.description, "MCP")
    end

    test "mcp_authoring supports authoring scope" do
      assert DefinedFeatures.feature_supports_scope?(:mcp_authoring, :authoring)
      assert DefinedFeatures.feature_supports_scope?("mcp_authoring", :authoring)
      refute DefinedFeatures.feature_supports_scope?(:mcp_authoring, :delivery)
    end

    test "all_features/0 includes mcp_authoring" do
      features = DefinedFeatures.all_features()

      feature_names = Enum.map(features, & &1.name)
      assert :mcp_authoring in feature_names
    end

    test "features_for_scope/1 includes mcp_authoring in authoring scope" do
      authoring_features = DefinedFeatures.features_for_scope(:authoring)
      delivery_features = DefinedFeatures.features_for_scope(:delivery)

      authoring_names = Enum.map(authoring_features, & &1.name)
      delivery_names = Enum.map(delivery_features, & &1.name)

      assert :mcp_authoring in authoring_names
      refute :mcp_authoring in delivery_names
    end

    test "feature_names/0 and feature_strings/0 include mcp_authoring" do
      assert :mcp_authoring in DefinedFeatures.feature_names()
      assert "mcp_authoring" in DefinedFeatures.feature_strings()
    end
  end

  describe "undefined features" do
    test "undefined features are not valid" do
      refute DefinedFeatures.valid_feature?(:undefined_feature)
      refute DefinedFeatures.valid_feature?("undefined_feature")
    end

    test "get_feature/1 returns nil for undefined features" do
      assert DefinedFeatures.get_feature(:undefined_feature) == nil
      assert DefinedFeatures.get_feature("undefined_feature") == nil
    end

    test "feature_supports_scope?/2 returns false for undefined features" do
      refute DefinedFeatures.feature_supports_scope?(:undefined_feature, :authoring)
      refute DefinedFeatures.feature_supports_scope?("undefined_feature", :authoring)
    end
  end
end
