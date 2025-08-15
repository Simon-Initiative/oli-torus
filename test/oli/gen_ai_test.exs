defmodule Oli.GenAITest do
  alias Oli.GenAI

  use Oli.DataCase
  alias Oli.Delivery.Sections
  alias Oli.GenAI.FeatureConfig

  @section_attrs %{
    open_and_free: true,
    requires_enrollment: true,
    registration_open: true,
    start_date: ~U[2010-04-17 00:00:00.000000Z],
    end_date: ~U[2010-05-17 00:00:00.000000Z],
    title: "some title",
    context_id: "context_id"
  }

  describe "registered models" do
    test "registered models crud" do
      {:ok, model} =
        GenAI.create_registered_model(%{
          name: "Test Model",
          provider: :open_ai,
          model: "gpt-3.5-turbo",
          url_template: "https://api.openai.com/v1/engines/{model}/completions",
          api_key: "test_api_key",
          timeout: 8000,
          recv_timeout: 60000
        })

      model = Oli.Repo.get(Oli.GenAI.Completions.RegisteredModel, model.id)
      assert model.name == "Test Model"
      assert model.provider == :open_ai
      assert model.model == "gpt-3.5-turbo"
      assert model.url_template == "https://api.openai.com/v1/engines/{model}/completions"
      assert model.api_key == "test_api_key"
      assert model.timeout == 8000
      assert model.recv_timeout == 60000

      m = GenAI.registered_models() |> Enum.reverse() |> hd
      assert m.id == model.id
      assert m.name == "Test Model"
      assert m.provider == :open_ai
      assert m.model == "gpt-3.5-turbo"
      assert m.url_template == "https://api.openai.com/v1/engines/{model}/completions"
      assert m.api_key == "test_api_key"
      assert m.timeout == 8000
      assert m.recv_timeout == 60000
      assert m.service_config_count == 0

      {:ok, service_config} =
        GenAI.create_service_config(%{
          name: "Test Service Config",
          primary_model_id: model.id,
          backup_model_id: nil
        })

      sc = Oli.Repo.get(Oli.GenAI.Completions.ServiceConfig, service_config.id)
      assert sc.name == "Test Service Config"
      assert sc.primary_model_id == model.id
      assert sc.backup_model_id == nil

      sc1 = GenAI.service_configs() |> Enum.reverse() |> hd
      assert sc1.id == sc.id
      assert sc1.name == "Test Service Config"
      assert sc1.primary_model_id == model.id
      assert sc1.backup_model_id == nil

      GenAI.delete_service_config(sc)
      assert Oli.Repo.get(Oli.GenAI.Completions.ServiceConfig, sc.id) == nil

      {:ok, updated_model} = GenAI.update_registered_model(model, %{name: "Updated Model"})
      updated_model = Oli.Repo.get(Oli.GenAI.Completions.RegisteredModel, updated_model.id)
      assert updated_model.name == "Updated Model"

      {:ok, _} = GenAI.delete_registered_model(updated_model)
      assert Oli.Repo.get(Oli.GenAI.Completions.RegisteredModel, updated_model.id) == nil
    end
  end

  describe "feature configs" do
    setup do
      map = Seeder.base_project_with_resource2()

      {:ok, section} =
        @section_attrs
        |> Map.put(:institution_id, map.institution.id)
        |> Map.put(:base_project_id, map.project.id)
        |> Sections.create_section()

      {:ok, section2} =
        @section_attrs
        |> Map.put(:institution_id, map.institution.id)
        |> Map.put(:base_project_id, map.project.id)
        |> Sections.create_section()

      {:ok,
       Map.merge(map, %{
         section: section,
         section2: section2
       })}
    end

    test "feature config crud", %{section: section, section2: section2} do
      {:ok, model} =
        GenAI.create_registered_model(%{
          name: "Test Model",
          provider: :open_ai,
          model: "gpt-3.5-turbo",
          url_template: "https://api.openai.com/v1/engines/{model}/completions",
          api_key: "test_api_key",
          timeout: 8000,
          recv_timeout: 60000
        })

      {:ok, service_config} =
        GenAI.create_service_config(%{
          name: "Test Service Config",
          primary_model_id: model.id,
          backup_model_id: nil
        })

      {:ok, feature_config} =
        GenAI.create_feature_config(%{
          feature: :student_dialogue,
          service_config_id: service_config.id,
          section_id: section.id
        })

      assert feature_config.feature == :student_dialogue
      assert feature_config.service_config_id == service_config.id
      assert feature_config.section_id == section.id

      assert GenAI.feature_config_exists?(:student_dialogue, section.id)
      refute GenAI.feature_config_exists?(:instructor_dashboard, section.id)
      refute GenAI.feature_config_exists?(:student_dialogue, section2.id)

      # We are loading a section specific config
      assert FeatureConfig.load_for(section.id, :student_dialogue).id == service_config.id

      # But an edit makes that section specific config no longer valid
      {:ok, updated_feature_config} =
        GenAI.update_feature_config(feature_config, %{feature: :instructor_dashboard})

      assert updated_feature_config.feature == :instructor_dashboard

      # after the previous edit, we now should expect to be loading the default
      # feature config for the section
      assert FeatureConfig.load_for(section.id, :student_dialogue).name == "standard-no-backup"

      {:ok, _} = GenAI.delete_feature_config(updated_feature_config)
      assert Oli.Repo.get(Oli.GenAI.FeatureConfig, updated_feature_config.id) == nil
    end
  end
end
