defmodule Oli.Repo.Migrations.AddKnowledgeBaseLinkAndSupportEmailToPublishers do
  use Ecto.Migration

  def change do
    alter table(:publishers) do
      add :knowledge_base_link, :string
      add :support_email, :string
    end
  end
end
