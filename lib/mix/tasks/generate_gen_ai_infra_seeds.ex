defmodule Mix.Tasks.GenerateGenAiInfraSeeds do
  use Mix.Task

  require Logger

  alias Oli.GenAI.Completions.RegisteredModel
  alias Oli.GenAI.Completions.ServiceConfig
  alias Oli.GenAIFeatureConfig

  @shortdoc "Seeds GenAI infrastructure data"

  @moduledoc """
  Seeds the database with GenAI infrastructure data including:
  - Registered models (OpenAI, Claude, Null provider)
  - Service configurations
  - Feature configurations

  ## Usage

      mix generate_gen_ai_infra_seeds

  ## Environment Variables

  The task will create models based on available API keys:
  - OPENAI_API_KEY: Creates OpenAI GPT-4 model
  - OPENAI_ORG_KEY: Secondary API key for OpenAI
  - ANTHROPIC_API_KEY: Creates Claude model

  If no API keys are available, only the null provider will be created.
  """

  def run(_args) do
    Mix.Task.run("app.start")

    # Check if data already exists
    case Oli.Repo.all(RegisteredModel) do
      [] ->
        Logger.info("🌱 Seeding GenAI infrastructure...")
        seed_gen_ai_data()
        Logger.info("✅ GenAI infrastructure seeded successfully!")

      _ ->
        Logger.info("🪴  GenAI infrastructure already exists")
        :ok
    end
  end

  defp seed_gen_ai_data do
    # Create registered models
    openai_model = maybe_create_openai_model()
    claude_model = maybe_create_claude_model()
    null_model = create_null_model()

    # Use the first available real model, or fallback to null
    primary_model = openai_model || claude_model || null_model

    # Create service config
    service_config = create_service_config(primary_model)

    # Create feature configs
    create_feature_configs(service_config)

    Logger.info("✨ Created models: #{list_created_models()}")
  end

  defp create_null_model do
    Logger.info(" ⏺️  Creating null provider model...")

    Oli.Repo.insert!(%RegisteredModel{
      name: "null",
      provider: :null,
      model: "null",
      url_template: "https://www.example.com"
    })
  end

  defp maybe_create_openai_model do
    case System.get_env("OPENAI_API_KEY") do
      nil ->
        Logger.info(" ⏭️  Skipping OpenAI model (no API key)")
        nil

      api_key ->
        Logger.info(" 🤖 Creating OpenAI GPT-4 model...")

        Oli.Repo.insert!(%RegisteredModel{
          name: "openai-gpt4",
          provider: :open_ai,
          model: "gpt-4-1106-preview",
          url_template: "https://api.openai.com",
          api_key: api_key,
          secondary_api_key: System.get_env("OPENAI_ORG_KEY")
        })
    end
  end

  defp maybe_create_claude_model do
    case System.get_env("ANTHROPIC_API_KEY") do
      nil ->
        Logger.info(" ⏭️  Skipping Claude model (no API key)")
        nil

      api_key ->
        Logger.info(" 🧠 Creating Claude model...")

        Oli.Repo.insert!(%RegisteredModel{
          name: "claude",
          provider: :claude,
          model: "claude-3-haiku-20240307",
          url_template: "https://api.anthropic.com/v1/messages",
          api_key: api_key
        })
    end
  end

  defp create_service_config(primary_model) do
    Logger.info(" ⚙️  Creating service configuration...")

    Oli.Repo.insert!(%ServiceConfig{
      name: "standard-no-backup",
      primary_model_id: primary_model.id,
      backup_model_id: nil
    })
  end

  defp create_feature_configs(service_config) do
    Logger.info(" 🎯 Creating feature configurations...")

    features = [
      {:student_dialogue, "Student Dialogue"},
      {:instructor_dashboard, "Instructor Dashboard"}
    ]

    Enum.each(features, fn {feature, name} ->
      Logger.info("    Creating #{name} feature config...")

      Oli.Repo.insert!(%GenAIFeatureConfig{
        feature: feature,
        service_config_id: service_config.id,
        section_id: nil
      })
    end)
  end

  defp list_created_models do
    Oli.Repo.all(RegisteredModel)
    |> Enum.map(& &1.name)
    |> Enum.join(", ")
  end
end
