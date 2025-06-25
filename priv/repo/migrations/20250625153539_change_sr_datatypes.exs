defmodule Oli.Repo.Migrations.ChangeSrDatatypes do
  use Ecto.Migration

  def change do
    execute("ALTER TABLE section_resources ALTER COLUMN title type text")
    execute("ALTER TABLE section_resources ALTER COLUMN poster_image type text")
    execute("ALTER TABLE section_resources ALTER COLUMN intro_video type text")
  end
end
3
