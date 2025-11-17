defmodule Oli.ScopedFeatureFlags.ScopedFeatureExemptionTest do
  use Oli.DataCase

  alias Oli.Inventories
  alias Oli.ScopedFeatureFlags.ScopedFeatureExemption

  describe "changeset/2" do
    test "is valid with required attributes" do
      {:ok, publisher} =
        Inventories.create_publisher(%{
          name: "Example Publisher #{System.unique_integer()}",
          email: "pub#{System.unique_integer()}@example.com",
          default: false
        })

      params = %{
        feature_name: "mcp_authoring",
        publisher_id: publisher.id,
        effect: :deny,
        note: "Legal opt-out"
      }

      changeset = ScopedFeatureExemption.changeset(%ScopedFeatureExemption{}, params)

      assert changeset.valid?
    end

    test "rejects unsupported effect" do
      {:ok, publisher} =
        Inventories.create_publisher(%{
          name: "Example Publisher #{System.unique_integer()}",
          email: "pub#{System.unique_integer()}@example.com",
          default: false
        })

      params = %{
        feature_name: "mcp_authoring",
        publisher_id: publisher.id,
        effect: :invalid_choice
      }

      changeset = ScopedFeatureExemption.changeset(%ScopedFeatureExemption{}, params)

      refute changeset.valid?
      assert {"is invalid", _} = changeset.errors[:effect]
    end
  end
end
