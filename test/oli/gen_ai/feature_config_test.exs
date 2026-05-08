defmodule Oli.GenAI.FeatureConfigTest do
  use Oli.DataCase, async: false

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
      # Seeded by priv/repo/seeds.exs as 'instructor-email-default'.
      loaded = FeatureConfig.load_for(nil, :instructor_email)
      assert loaded.name == "instructor-email-default"
      refute is_nil(loaded.primary_model_id)
    end

    test "with nil section_id, returns the seeded global ServiceConfig for :instructor_dashboard_recommendation" do
      # Confirms the fix did not regress existing global-default resolution.
      loaded = FeatureConfig.load_for(nil, :instructor_dashboard_recommendation)
      assert loaded.name == "standard-no-backup"
    end

    test "with a non-nil section_id and no section override, falls back to the global default" do
      # Branch coverage for the `else` arm of the new `if is_nil(section_id)` guard.
      # No FeatureConfig row exists with a section_id, so the global default
      # should be returned for any section the caller asks about.
      loaded = FeatureConfig.load_for(99_999_999, :instructor_email)
      assert loaded.name == "instructor-email-default"
    end
  end
end
