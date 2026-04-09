defmodule Oli.FeaturesTest do
  use Oli.DataCase

  alias Oli.Features
  alias Oli.Features.Feature

  describe "features" do
    setup do
      Oli.Seeder.base_project_with_resource2()
    end

    test "basic operations of feature flags", _ do
      [{%Feature{label: "adaptivity"}, state} | _] = Features.list_features_and_states()
      assert state == :enabled

      assert Features.enabled?("adaptivity")

      Features.change_state("adaptivity", :enabled)

      [{%Feature{label: "adaptivity"}, state} | _] = Features.list_features_and_states()
      assert state == :enabled

      assert Features.enabled?("adaptivity")
    end

    test "lti new tab fallback is disabled by default", _ do
      Features.bootstrap_feature_states()
      refute Features.enabled?("lti-new-tab-fallback")
    end

    test "lti storage target is enabled by default", _ do
      Features.bootstrap_feature_states()
      assert Features.enabled?("lti-storage-target")
    end
  end
end
