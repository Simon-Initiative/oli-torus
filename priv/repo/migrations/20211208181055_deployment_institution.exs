defmodule Oli.Repo.Migrations.DeploymentInstitution do
  use Ecto.Migration
  import Ecto.Query, warn: false

  alias Oli.Repo

  def up do

    alter table(:lti_1p3_deployments) do
      add :institution_id, references(:institutions)
    end

    alter table(:institutions) do
      add :default_brand_id, references(:brands)
    end

    alter table(:pending_registrations) do
      add :deployment_id, :string
    end

    flush()

    {deployment_institution, institution_brand} =
      from(d in "lti_1p3_deployments",
        join: r in "lti_1p3_registrations",
        on: r.id == d.registration_id,
        select: %{id: d.id, institution_id: r.institution_id, brand_id: r.brand_id}
    )
    |> Repo.all()
    |> Enum.reduce({%{}, %{}}, fn %{id: d_id, institution_id: institution_id, brand_id: brand_id}, {deployment_institution, institution_brand} ->
      {
        Map.put(deployment_institution, d_id, institution_id),
        if brand_id == nil do
          institution_brand
        else
          Map.put_new(institution_brand, institution_id, brand_id)
        end
      }
    end)

    # populate all existing deployments with the institution_id inferred from registration
    deployment_institution
    |> Enum.each(fn {id, institution_id} ->
      deployment_query = from(d in "lti_1p3_deployments", where: d.id == ^id)
      Repo.update_all(deployment_query, set: [institution_id: institution_id])
    end)

    # populate default_brand_id inferred from registration if it is set
    institution_brand
    |> Enum.each(fn {id, brand_id} ->
      institution_query = from(i in "institutions", where: i.id == ^id)
      Repo.update_all(institution_query, set: [default_brand_id: brand_id])
    end)

    flush()

    alter table(:lti_1p3_registrations) do
      remove :institution_id, references(:institutions)
      remove :brand_id, references(:brands)
    end

  end

  def down do

    alter table(:lti_1p3_registrations) do
      add :institution_id, references(:institutions)
      add :brand_id, references(:institutions)
    end

    flush()

    # restore institution_id and brand_id to registration from deployment and institution's brand
    from(r in "lti_1p3_registrations",
      join: d in "lti_1p3_deployments",
      on: d.registration_id == r.id,
      join: i in "institutions",
      on: i.id == d.institution_id,
      join: b in "brands",
      on: b.id == i.default_brand_id,
      select: %{id: r.id, institution_id: i.id, brand_id: b.id}
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn %{id: id, institution_id: institution_id, brand_id: brand_id}, acc ->
      Map.put_new(acc, id, {institution_id, brand_id})
    end)
    |> Enum.each(fn {id, {institution_id, brand_id}} ->
      registration = from(r in "lti_1p3_registrations", where: r.id == ^id)
      Repo.update_all(registration, set: [institution_id: institution_id, brand_id: brand_id])
    end)

    flush()

    alter table(:pending_registrations) do
      remove :deployment_id, :string
    end

    alter table(:institutions) do
      remove :default_brand_id, references(:brands)
    end

    alter table(:lti_1p3_deployments) do
      remove :institution_id, references(:institutions)
    end

  end
end
