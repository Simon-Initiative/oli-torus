defmodule Oli.Repo.Migrations.CreateLti1p3Platforms do
  use Ecto.Migration

  def change do
    create table(:lti_1p3_platform_instances) do
      add :name, :string
      add :description, :text
      add :target_link_uri, :string
      add :client_id, :string
      add :login_url, :string
      add :keyset_url, :string
      add :redirect_uris, :text
      add :custom_params, :text

      timestamps()
    end

  end
end
