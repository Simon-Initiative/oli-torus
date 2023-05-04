defmodule Oli.Repo.Migrations.OptionalContentTypes do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :allow_ecl_content_type, :boolean, default: false
    end
  end
end
