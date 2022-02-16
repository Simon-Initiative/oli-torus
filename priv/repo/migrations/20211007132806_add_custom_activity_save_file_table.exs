defmodule Oli.Repo.Migrations.AddCustomActivitySaveFileTable do
  use Ecto.Migration

  def change do
    create table(:activity_attempt_save_files) do
      add :attempt_guid, :string
      add :user_id, :string
      add :attempt_number, :integer
      add :file_name, :string
      add :file_guid, :string
      add :content, :text
      add :mime_type, :string
      add :byte_encoding, :string
      add :activity_type, :string
      timestamps(type: :timestamptz)
    end

    create index(:activity_attempt_save_files, [:attempt_guid])
    create index(:activity_attempt_save_files, [:file_guid])
    create unique_index(:activity_attempt_save_files, [:attempt_guid, :user_id, :file_name], name: :index_activity_user_save_files)

    alter table(:activity_attempts) do
      add :date_completed, :utc_datetime
      add :custom_scores, :map
    end

  end
end
