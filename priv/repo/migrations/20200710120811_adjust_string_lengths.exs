defmodule Oli.Repo.Migrations.AdjustStringLengths do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      modify :lti_lineitems_url, :text
      modify :canvas_url, :text
    end

    alter table(:activity_registrations) do
      modify :description, :text
    end

    alter table(:revisions) do
      modify :title, :text
    end

    alter table(:media_items) do
      modify :url, :text
    end

    alter table(:themes) do
      modify :url, :text
    end
  end
end
