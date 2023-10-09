defmodule Oli.Repo.Migrations.AddMostRecentlyVisitedResourceIdToEnrollments do
  use Ecto.Migration

  def change do
    alter table(:enrollments) do
      add :most_recently_visited_resource_id, references(:resources)
    end
  end
end
