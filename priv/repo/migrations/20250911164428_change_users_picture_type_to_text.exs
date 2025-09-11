defmodule Oli.Repo.Migrations.ChangeUsersPictureTypeToText do
  use Ecto.Migration

  def change do
    alter table("users") do
      modify :picture, :text, from: :string
    end
  end
end
