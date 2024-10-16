defmodule Oli.Repo.Migrations.ReplicateRevisionFields do
  use Ecto.Migration

  def change do
    alter table(:section_resources) do
      add :project_slug, :string
      add :title, :string
      add :graded, :boolean
      add :revision_slug, :string
      add :purpose, :string
      add :duration_minutes, :integer
      add :intro_content, :map, default: %{}
      add :intro_video, :string, default: nil
      add :poster_image, :string, default: nil
      add :objectives, :map, default: %{}
      add :relates_to, {:array, :id}, default: []
      add :resource_type_id, references(:resource_types, on_delete: :delete_all)
      add :activity_type_id, references(:activity_registrations, on_delete: :delete_all)
      add :revision_id, references(:revisions, on_delete: :delete_all)
    end
  end
end
