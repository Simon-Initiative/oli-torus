defmodule Oli.Repo.Migrations.UserLoginToken do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :login_token, :string
    end

    # TODO: create login_token for existing open and free users (or combine this migration with 20210310153047_open_and_free.exs)
  end
end
