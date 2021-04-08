defmodule OliWeb.DeploymentController do
  use OliWeb, :controller

  alias Oli.Institutions
  alias Lti_1p3.DataProviders.EctoProvider.Deployment

  def new(conn, %{"institution_id" => institution_id, "registration_id" => registration_id}) do
    changeset = Institutions.change_deployment(%Deployment{registration_id: registration_id})

    render(conn, "new.html",
      changeset: changeset,
      institution_id: institution_id,
      registration_id: registration_id,
      title: "Create Deployment"
    )
  end

  def create(conn, %{
        "institution_id" => institution_id,
        "registration_id" => registration_id,
        "deployment" => deployment_params
      }) do
    deployment_params =
      deployment_params
      |> Map.put("registration_id", registration_id)

    case Institutions.create_deployment(deployment_params) do
      {:ok, _deployment} ->
        conn
        |> put_flash(:info, "Deployment created successfully.")
        |> redirect(to: Routes.institution_path(conn, :show, institution_id))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html",
          changeset: changeset,
          institution_id: institution_id,
          registration_id: registration_id,
          title: "Create Deployment"
        )
    end
  end

  def edit(conn, %{
        "institution_id" => institution_id,
        "registration_id" => registration_id,
        "id" => id
      }) do
    deployment = Institutions.get_deployment!(id)
    changeset = Institutions.change_deployment(deployment)

    render(conn, "edit.html",
      deployment: deployment,
      changeset: changeset,
      institution_id: institution_id,
      registration_id: registration_id,
      title: "Edit Deployment"
    )
  end

  def update(conn, %{
        "institution_id" => institution_id,
        "registration_id" => registration_id,
        "id" => id,
        "deployment" => deployment_params
      }) do
    deployment = Institutions.get_deployment!(id)

    case Institutions.update_deployment(deployment, deployment_params) do
      {:ok, _deployment} ->
        conn
        |> put_flash(:info, "Deployment updated successfully.")
        |> redirect(to: Routes.institution_path(conn, :show, institution_id))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html",
          deployment: deployment,
          changeset: changeset,
          institution_id: institution_id,
          registration_id: registration_id,
          title: "Edit Deployment"
        )
    end
  end

  def delete(conn, %{
        "institution_id" => institution_id,
        "registration_id" => _registration_id,
        "id" => id
      }) do
    deployment = Institutions.get_deployment!(id)
    {:ok, _deployment} = Institutions.delete_deployment(deployment)

    conn
    |> put_flash(:info, "Deployment deleted successfully.")
    |> redirect(to: Routes.institution_path(conn, :show, institution_id))
  end
end
