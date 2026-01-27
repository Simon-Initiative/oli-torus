defmodule Oli.GenAI.ServiceConfigChangesetTest do
  use Oli.DataCase, async: true

  alias Oli.GenAI.Completions.ServiceConfig

  describe "routing policy validations" do
    test "defaults are present on new changeset" do
      changeset =
        ServiceConfig.changeset(%ServiceConfig{}, %{name: "Default Config", primary_model_id: 1})

      assert changeset.valid?
      assert get_field(changeset, :routing_soft_limit) == 40
      assert get_field(changeset, :routing_hard_limit) == 80
      assert get_field(changeset, :routing_timeout_ms) == 30_000
      assert get_field(changeset, :routing_connect_timeout_ms) == 5_000
    end

    test "rejects soft limit greater than hard limit" do
      changeset =
        ServiceConfig.changeset(%ServiceConfig{}, %{
          name: "Invalid Config",
          primary_model_id: 1,
          routing_soft_limit: 10,
          routing_hard_limit: 5
        })

      refute changeset.valid?
      assert "must be less than or equal to hard limit" in errors_on(changeset).routing_soft_limit
    end

    test "rejects negative routing limits" do
      changeset =
        ServiceConfig.changeset(%ServiceConfig{}, %{
          name: "Negative Config",
          primary_model_id: 1,
          routing_timeout_ms: -10
        })

      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).routing_timeout_ms
    end
  end

  describe "secondary model validations" do
    test "allows nil secondary model" do
      changeset =
        ServiceConfig.changeset(%ServiceConfig{}, %{
          name: "Config",
          primary_model_id: 1,
          backup_model_id: 2
        })

      assert changeset.valid?
    end

    test "rejects secondary model matching primary model" do
      changeset =
        ServiceConfig.changeset(%ServiceConfig{}, %{
          name: "Config",
          primary_model_id: 1,
          secondary_model_id: 1
        })

      refute changeset.valid?
      assert "must be different from primary model" in errors_on(changeset).secondary_model_id
    end

    test "rejects secondary model matching backup model" do
      changeset =
        ServiceConfig.changeset(%ServiceConfig{}, %{
          name: "Config",
          primary_model_id: 1,
          secondary_model_id: 2,
          backup_model_id: 2
        })

      refute changeset.valid?
      assert "must be different from backup model" in errors_on(changeset).secondary_model_id
    end
  end
end
