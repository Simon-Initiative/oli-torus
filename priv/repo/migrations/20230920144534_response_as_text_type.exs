defmodule Oli.Repo.Migrations.ResponseAsTextType do
  use Ecto.Migration

  def change do
    alter table(:resource_part_responses) do
      modify(:response, :text, from: :string)
      modify(:label, :text, from: :string)
    end
  end
end
