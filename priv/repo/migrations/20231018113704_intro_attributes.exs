defmodule Oli.Repo.Migrations.IntroAttributes do
  use Ecto.Migration

  def change do
    alter table(:revisions) do
      add :duration_minutes, :integer
      add :intro_content, :map
      add :intro_video, :text
      add :poster_image, :text
    end
  end
end
