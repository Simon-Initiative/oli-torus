defmodule Oli.Repo.Migrations.CognitoSsoJwksStore do
  use Ecto.Migration

  def change do
    create table(:sso_jwks) do
      add :pem, :text
      add :typ, :string
      add :alg, :string
      add :kid, :string

      timestamps(type: :timestamptz)
    end
  end
end
