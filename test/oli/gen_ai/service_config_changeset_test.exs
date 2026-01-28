defmodule Oli.GenAI.ServiceConfigChangesetTest do
  use Oli.DataCase, async: true

  alias Oli.GenAI.Completions.ServiceConfig

  describe "routing policy validations" do
    test "defaults are present on new changeset" do
      changeset =
        ServiceConfig.changeset(%ServiceConfig{}, %{name: "Default Config", primary_model_id: 1})

      assert changeset.valid?
    end

    test "requires primary model id" do
      changeset = ServiceConfig.changeset(%ServiceConfig{}, %{name: "Missing Primary"})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).primary_model_id
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
