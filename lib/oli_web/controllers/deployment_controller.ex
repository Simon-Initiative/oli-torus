defmodule OliWeb.DeploymentController do
  use OliWeb, :controller

  alias Oli.Institutions
  alias Oli.Lti_1p3.Tool.Deployment
  alias OliWeb.Common.{Breadcrumb}

  def root_breadcrumbs(registration_id) do
    OliWeb.RegistrationController.root_breadcrumbs() ++
      [
        Breadcrumb.new(%{
          full_title: "#{registration_id}",
          link: Routes.registration_path(OliWeb.Endpoint, :show, registration_id)
        }),
        Breadcrumb.new(%{
          full_title: "Deployments",
          link: Routes.registration_path(OliWeb.Endpoint, :show, registration_id)
        })
      ]
  end

  def breadcrumbs(registration_id, name) do
    root_breadcrumbs(registration_id) ++
      [
        Breadcrumb.new(%{
          full_title: name
        })
      ]
  end

  defp available_institutions() do
    Institutions.list_institutions()
    |> Enum.map(fn i -> {i.name, i.id} end)
  end

  def new(conn, %{"registration_id" => registration_id}) do
    changeset = Institutions.change_deployment(%Deployment{registration_id: registration_id})

    render(conn, "new.html",
      changeset: changeset,
      registration_id: registration_id,
      breadcrumbs: breadcrumbs(registration_id, "New"),
      available_institutions: available_institutions(),
      title: "Create Deployment"
    )
  end

  def create(conn, %{
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
        |> redirect(to: Routes.registration_path(conn, :show, registration_id))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html",
          changeset: changeset,
          registration_id: registration_id,
          breadcrumbs: breadcrumbs(registration_id, "New"),
          available_institutions: available_institutions(),
          title: "Create Deployment"
        )
    end
  end

  def edit(conn, %{
        "registration_id" => registration_id,
        "id" => id
      }) do
    deployment = Institutions.get_deployment!(id)
    changeset = Institutions.change_deployment(deployment)

    render(conn, "edit.html",
      deployment: deployment,
      changeset: changeset,
      registration_id: registration_id,
      breadcrumbs: breadcrumbs(registration_id, "Edit"),
      available_institutions: available_institutions(),
      title: "Edit Deployment"
    )
  end

  def update(conn, %{
        "registration_id" => registration_id,
        "id" => id,
        "deployment" => deployment_params
      }) do
    deployment = Institutions.get_deployment!(id)

    case Institutions.update_deployment(deployment, deployment_params) do
      {:ok, _deployment} ->
        conn
        |> put_flash(:info, "Deployment updated successfully.")
        |> redirect(to: Routes.registration_path(conn, :show, registration_id))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html",
          deployment: deployment,
          changeset: changeset,
          breadcrumbs: breadcrumbs(registration_id, "Edit"),
          registration_id: registration_id,
          available_institutions: available_institutions(),
          title: "Edit Deployment"
        )
    end
  end

  def delete(conn, %{
        "registration_id" => registration_id,
        "id" => id
      }) do
    deployment = Institutions.get_deployment!(id)
    {:ok, _deployment} = Institutions.delete_deployment(deployment)

    conn
    |> put_flash(:info, "Deployment deleted successfully.")
    |> redirect(to: Routes.registration_path(conn, :show, registration_id))
  end
end
