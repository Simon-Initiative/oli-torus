defmodule Oli.Repo.Migrations.AddWelcomeTitleAndEncouragingSubtitleToSections do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add(:welcome_title, :text)
      add(:encouraging_subtitle, :text)
    end
  end
end
