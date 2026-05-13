defmodule Oli.GenAI.FeatureConfigTest do
  use Oli.DataCase, async: false

  import Ecto.Query

  alias Oli.GenAI.Completions.ServiceConfig
  alias Oli.GenAI.FeatureConfig

  describe "features/0" do
    test "lists :student_dialogue, :instructor_dashboard_recommendation, and :instructor_email" do
      features = FeatureConfig.features()

      assert :student_dialogue in features
      assert :instructor_dashboard_recommendation in features
      assert :instructor_email in features
    end
  end

  describe "Ecto.Enum on :feature accepts :instructor_email" do
    setup do
      {:ok, model} =
        Oli.GenAI.create_registered_model(%{
          name: "instructor-email-test-model",
          provider: :open_ai,
          model: "gpt-test",
          url_template: "https://api.example.com",
          api_key: "test_api_key"
        })

      service_config =
        Repo.insert!(%ServiceConfig{
          name: "instructor-email-test-service",
          primary_model_id: model.id,
          backup_model_id: nil
        })

      %{service_config: service_config}
    end

    test "inserts a global FeatureConfig with feature: :instructor_email", %{
      service_config: service_config
    } do
      changeset =
        FeatureConfig.changeset(%FeatureConfig{}, %{
          feature: :instructor_email,
          service_config_id: service_config.id,
          section_id: nil
        })

      assert {:ok, %FeatureConfig{} = inserted} = Repo.insert(changeset)
      assert inserted.feature == :instructor_email
      assert inserted.service_config_id == service_config.id
      assert is_nil(inserted.section_id)
    end

    test "rejects an unknown feature atom" do
      changeset =
        FeatureConfig.changeset(%FeatureConfig{}, %{
          feature: :unknown_feature,
          service_config_id: nil,
          section_id: nil
        })

      refute changeset.valid?
      assert %{feature: [_ | _]} = errors_on(changeset)
    end
  end

  describe "load_for/2 — global default resolution (regression for nil section_id bug)" do
    test "with nil section_id, returns the seeded global ServiceConfig for :instructor_email" do
      assert {:ok, loaded} = FeatureConfig.load_for(nil, :instructor_email)
      assert loaded.name == "instructor-email-default"
      refute is_nil(loaded.primary_model_id)
    end

    test "with nil section_id, returns the seeded global ServiceConfig for :instructor_dashboard_recommendation" do
      assert {:ok, loaded} = FeatureConfig.load_for(nil, :instructor_dashboard_recommendation)
      assert loaded.name == "standard-no-backup"
    end

    test "with a non-nil section_id and no section override, falls back to the global default" do
      assert {:ok, loaded} = FeatureConfig.load_for(99_999_999, :instructor_email)
      assert loaded.name == "instructor-email-default"
    end
  end

  describe "load_for/2 — missing config" do
    test "returns {:error, {:missing_feature_config, _}} for a feature with no row at nil section" do
      # No FeatureConfig row exists for the placeholder feature atom; the
      # function must return the error tuple, not raise.
      # We need a feature value that's in @features but has no seeded row;
      # since all currently registered features ARE seeded, we test via a
      # section_id without override and a feature that has no global row by
      # deleting the seeded row first.
      Oli.Repo.delete_all(
        from(g in FeatureConfig,
          where: g.feature == :instructor_email and is_nil(g.section_id)
        )
      )

      assert {:error, {:missing_feature_config, msg}} =
               FeatureConfig.load_for(nil, :instructor_email)

      assert msg =~ "global"
    end
  end

  describe "load_for/2 — unsupported feature atom" do
    test "returns {:error, _} instead of raising Ecto.Query.CastError" do
      assert {:error, {:missing_feature_config, msg}} =
               FeatureConfig.load_for(nil, :totally_bogus_feature)

      assert msg =~ "Unsupported feature"
      assert msg =~ "totally_bogus_feature"
    end

    test "returns {:error, _} for unknown atom with integer section_id" do
      assert {:error, {:missing_feature_config, _}} =
               FeatureConfig.load_for(42, :another_bogus)
    end
  end
end
