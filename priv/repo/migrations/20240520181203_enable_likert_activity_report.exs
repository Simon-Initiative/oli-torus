defmodule Oli.Repo.Migrations.EnableLikertActivityReport do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE activity_registrations SET generates_report = true WHERE slug = 'oli_likert';
    """)
  end
end
