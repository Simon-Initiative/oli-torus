defmodule Oli.GenAI.Dev.LocalCodexTest do
  use Oli.DataCase

  alias Oli.Delivery.Sections
  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig}
  alias Oli.GenAI.Dev.LocalCodex
  alias Oli.GenAI.FeatureConfig

  @section_attrs %{
    context_id: "context_id",
    end_date: ~U[2010-05-17 00:00:00.000000Z],
    open_and_free: true,
    registration_open: true,
    requires_enrollment: true,
    start_date: ~U[2010-04-17 00:00:00.000000Z],
    title: "some title"
  }

  describe "setup/1" do
    test "creates and updates a global student dialogue config idempotently" do
      initial_model_count = Repo.aggregate(RegisteredModel, :count, :id)
      initial_service_count = Repo.aggregate(ServiceConfig, :count, :id)

      initial_global_feature_count =
        from(fc in FeatureConfig,
          where: fc.feature == :student_dialogue and is_nil(fc.section_id)
        )
        |> Repo.aggregate(:count, :id)

      assert {:ok, first} = LocalCodex.setup(%{})

      assert first.registered_model.provider == :open_ai
      assert first.registered_model.url_template == "http://localhost:4001"
      assert first.service_config.primary_model_id == first.registered_model.id
      assert first.feature_config.feature == :student_dialogue
      assert is_nil(first.feature_config.section_id)

      assert {:ok, second} =
               LocalCodex.setup(%{
                 model: "codex-proxy-v2",
                 url: "http://localhost:4010"
               })

      assert first.registered_model.id == second.registered_model.id
      assert first.service_config.id == second.service_config.id
      assert first.feature_config.id == second.feature_config.id

      assert Repo.aggregate(RegisteredModel, :count, :id) == initial_model_count + 1
      assert Repo.aggregate(ServiceConfig, :count, :id) == initial_service_count + 1

      assert from(fc in FeatureConfig,
               where: fc.feature == :student_dialogue and is_nil(fc.section_id)
             )
             |> Repo.aggregate(:count, :id) == initial_global_feature_count

      updated_model = Repo.get!(RegisteredModel, second.registered_model.id)
      assert updated_model.model == "codex-proxy-v2"
      assert updated_model.url_template == "http://localhost:4010"
      assert updated_model.routing_breaker_error_rate_threshold == 0.0
      assert updated_model.routing_breaker_429_threshold == 0.0
      assert updated_model.routing_breaker_latency_p95_ms == 0
    end

    test "creates a section-specific feature config when section_id is provided" do
      map = Seeder.base_project_with_resource2()

      {:ok, section} =
        @section_attrs
        |> Map.put(:base_project_id, map.project.id)
        |> Map.put(:institution_id, map.institution.id)
        |> Sections.create_section()

      assert {:ok, result} = LocalCodex.setup(%{section_id: section.id})

      assert result.feature_config.section_id == section.id
      assert result.feature_config.feature == :student_dialogue

      assert Repo.get_by(RegisteredModel, name: "local-codex-proxy")
      assert Repo.get_by(ServiceConfig, name: "local-codex-proxy")
      assert Repo.get_by(FeatureConfig, feature: :student_dialogue, section_id: section.id)
    end
  end
end
