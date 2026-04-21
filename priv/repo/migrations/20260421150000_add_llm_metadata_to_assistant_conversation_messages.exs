defmodule Oli.Repo.Migrations.AddLlmMetadataToAssistantConversationMessages do
  use Ecto.Migration

  def change do
    alter table(:assistant_conversation_messages) do
      add :llm_provider_type, :string
      add :llm_provider_url, :text
      add :llm_model, :string
    end
  end
end
