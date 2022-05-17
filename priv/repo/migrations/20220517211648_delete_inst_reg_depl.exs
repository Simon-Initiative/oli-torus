defmodule Oli.Repo.Migrations.DeleteInstRegDepl do
  use Ecto.Migration
  import Ecto.Query, warn: false

  alias Oli.Repo

  def up do
    drop(constraint(:sections, "sections_lti_1p3_deployment_id_fkey"))

    alter table(:sections) do
      modify :lti_1p3_deployment_id, references(:lti_1p3_deployments, on_delete: :nilify_all)
    end
  end

  def down do
    drop(constraint(:sections, "sections_lti_1p3_deployment_id_fkey"))

    # we need somewhere to put any orphaned registrations and deployments and sections
    # so we create a new institution, registration and deployment to associate with
    now = DateTime.utc_now()
    today = Enum.join([now.month, now.day, now.year], "/")

    {_, [%{id: institution_id}]} =
      Repo.insert_all(
        "institutions",
        [
          %{
            name: "Migration Rollback Orphans #{today}",
            country_code: "UNKNOWN",
            institution_email: "UNKNOWN",
            institution_url: "UNKNOWN",
            timezone: "UNKNOWN",
            inserted_at: now,
            updated_at: now
          }
        ],
        returning: [:id]
      )

    {:ok, %{id: jwk_id}} = Lti_1p3.get_active_jwk()

    {_, [%{id: registration_id}]} =
      Repo.insert_all(
        "lti_1p3_registrations",
        [
          %{
            tool_jwk_id: jwk_id,
            issuer: "UNKNOWN",
            client_id: "UNKNOWN",
            key_set_url: "UNKNOWN",
            auth_token_url: "UNKNOWN",
            auth_login_url: "UNKNOWN",
            auth_server: "UNKNOWN",
            inserted_at: now,
            updated_at: now
          }
        ],
        returning: [:id],
        conflict_target: [:issuer, :client_id],
        on_conflict: {:replace, [:issuer, :client_id]}
      )

    {_, [%{id: deployment_id}]} =
      Repo.insert_all(
        "lti_1p3_deployments",
        [
          %{
            deployment_id: "UNKNOWN",
            registration_id: registration_id,
            institution_id: institution_id,
            inserted_at: now,
            updated_at: now
          }
        ],
        returning: [:id]
      )

    from(s in "sections",
      where: is_nil(s.lti_1p3_deployment_id),
      update: [set: [lti_1p3_deployment_id: ^deployment_id]]
    )
    |> Repo.update_all([])

    flush()

    alter table(:sections) do
      modify :lti_1p3_deployment_id, references(:lti_1p3_deployments, on_delete: :nothing)
    end
  end
end
