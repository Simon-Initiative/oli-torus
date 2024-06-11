defmodule Oli.Repo.Migrations.AddWelcomeTitleAndEncouragingSubtitleToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add(:welcome_title, :text)
      add(:encouraging_subtitle, :text)
    end
  end
end
