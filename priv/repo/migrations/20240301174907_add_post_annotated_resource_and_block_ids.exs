defmodule Oli.Repo.Migrations.AddPostAnnotatedResourceAndBlockIds do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :annotated_resource_id, references(:resources, on_delete: :nothing)
      add :annotated_block_id, :string
      add :annotation_type, :string, default: "none"
      add :visibility, :string, default: "private"
    end
  end
end
