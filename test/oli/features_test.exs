defmodule Oli.FeaturesTest do
  use Oli.DataCase

  alias Oli.Features
  alias Oli.Features.Feature

  describe "features" do
    setup do
      Oli.Seeder.base_project_with_resource2()
    end

    test "basic operations of feature flags", _ do
      [{%Feature{id: 1, label: "adaptivity"}, state}] = Features.list_features_and_states()
      assert state == :disabled

      refute Features.enabled?("adaptivity")

      Features.change_state("adaptivity", :enabled)
      [{%Feature{id: 1, label: "adaptivity"}, state}] = Features.list_features_and_states()
      assert state == :enabled

      assert Features.enabled?("adaptivity")
    end
  end
end
