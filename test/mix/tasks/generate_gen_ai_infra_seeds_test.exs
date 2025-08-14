defmodule Mix.Tasks.GenerateGenAiInfraSeedsTest do
  use Oli.DataCase

  alias Mix.Tasks.GenerateGenAiInfraSeeds
  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig}
  alias Oli.GenAIFeatureConfig

  describe "run/1" do
    setup do
      # Clean up environment variables
      System.delete_env("OPENAI_API_KEY")
      System.delete_env("OPENAI_ORG_KEY")
      System.delete_env("ANTHROPIC_API_KEY")
    end

    test "creates null provider when no API keys are available" do
      # Ensure no API keys are set
      System.delete_env("OPENAI_API_KEY")
      System.delete_env("ANTHROPIC_API_KEY")

      assert :ok == GenerateGenAiInfraSeeds.run([])

      # Verify null model was created
      null_model = Oli.Repo.get_by(RegisteredModel, name: "null")
      assert null_model != nil
      assert null_model.provider == :null
      assert null_model.model == "null"
      assert null_model.url_template == "https://www.example.com"

      # Verify service config was created
      service_config = Oli.Repo.get_by(ServiceConfig, name: "standard-no-backup")
      assert service_config != nil
      assert service_config.primary_model_id == null_model.id
      assert service_config.backup_model_id == nil

      # Verify feature configs were created
      student_dialogue_config = Oli.Repo.get_by(GenAIFeatureConfig, feature: :student_dialogue)

      assert student_dialogue_config
      assert student_dialogue_config.service_config_id == service_config.id
      refute student_dialogue_config.section_id

      instructor_dashboard_config =
        Oli.Repo.get_by(GenAIFeatureConfig, feature: :instructor_dashboard)

      assert instructor_dashboard_config
      assert instructor_dashboard_config.service_config_id == service_config.id
      refute instructor_dashboard_config.section_id
    end

    test "creates OpenAI model when OPENAI_API_KEY is available" do
      # Set OpenAI API key
      System.put_env("OPENAI_API_KEY", "sk-test-openai-key")
      System.put_env("OPENAI_ORG_KEY", "org-test-key")

      assert :ok == GenerateGenAiInfraSeeds.run([])

      # Verify OpenAI model was created
      openai_model = Oli.Repo.get_by(RegisteredModel, name: "openai-gpt4")
      assert openai_model
      assert openai_model.provider == :open_ai
      assert openai_model.model == "gpt-4-1106-preview"
      assert openai_model.url_template == "https://api.openai.com"
      assert openai_model.api_key == "sk-test-openai-key"
      assert openai_model.secondary_api_key == "org-test-key"

      # Verify null model was also created
      null_model = Oli.Repo.get_by(RegisteredModel, name: "null")
      assert null_model

      # Verify service config uses OpenAI as primary
      service_config = Oli.Repo.get_by(ServiceConfig, name: "standard-no-backup")
      assert service_config
      assert service_config.primary_model_id == openai_model.id
    end

    test "creates Claude model when ANTHROPIC_API_KEY is available" do
      # Set Anthropic API key
      System.put_env("ANTHROPIC_API_KEY", "sk-ant-test-claude-key")

      assert :ok == GenerateGenAiInfraSeeds.run([])

      # Verify Claude model was created
      claude_model = Oli.Repo.get_by(RegisteredModel, name: "claude")
      assert claude_model
      assert claude_model.provider == :claude
      assert claude_model.model == "claude-3-haiku-20240307"
      assert claude_model.url_template == "https://api.anthropic.com/v1/messages"
      assert claude_model.api_key == "sk-ant-test-claude-key"
      refute claude_model.secondary_api_key

      # Verify null model was also created
      null_model = Oli.Repo.get_by(RegisteredModel, name: "null")
      assert null_model

      # Verify service config uses Claude as primary
      service_config = Oli.Repo.get_by(ServiceConfig, name: "standard-no-backup")
      assert service_config
      assert service_config.primary_model_id == claude_model.id
    end

    test "creates both OpenAI and Claude models when both API keys are available" do
      # Set both API keys
      System.put_env("OPENAI_API_KEY", "sk-test-openai-key")
      System.put_env("ANTHROPIC_API_KEY", "sk-ant-test-claude-key")

      assert :ok == GenerateGenAiInfraSeeds.run([])

      # Verify both models were created
      openai_model = Oli.Repo.get_by(RegisteredModel, name: "openai-gpt4")
      assert openai_model
      assert openai_model.provider == :open_ai

      claude_model = Oli.Repo.get_by(RegisteredModel, name: "claude")
      assert claude_model
      assert claude_model.provider == :claude

      null_model = Oli.Repo.get_by(RegisteredModel, name: "null")
      assert null_model

      # Verify service config uses OpenAI as primary (first in order)
      service_config = Oli.Repo.get_by(ServiceConfig, name: "standard-no-backup")
      assert service_config
      assert service_config.primary_model_id == openai_model.id
    end

    test "does not create duplicate data when run multiple times" do
      # Set API key
      System.put_env("OPENAI_API_KEY", "sk-test-openai-key")

      # Run first time
      assert :ok == GenerateGenAiInfraSeeds.run([])

      # Count records after first run
      initial_model_count = Oli.Repo.aggregate(RegisteredModel, :count, :id)
      initial_service_count = Oli.Repo.aggregate(ServiceConfig, :count, :id)
      initial_feature_count = Oli.Repo.aggregate(GenAIFeatureConfig, :count, :id)

      # Run second time
      assert :ok == GenerateGenAiInfraSeeds.run([])

      # Verify no additional records were created
      assert Oli.Repo.aggregate(RegisteredModel, :count, :id) == initial_model_count
      assert Oli.Repo.aggregate(ServiceConfig, :count, :id) == initial_service_count
      assert Oli.Repo.aggregate(GenAIFeatureConfig, :count, :id) == initial_feature_count
    end
  end
end
