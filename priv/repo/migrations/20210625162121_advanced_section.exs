defmodule Oli.Repo.Migrations.AdvancedSection do
  use Ecto.Migration

  def change do

    rename table(:sections), :time_zone, to: :timezone

  end
end
