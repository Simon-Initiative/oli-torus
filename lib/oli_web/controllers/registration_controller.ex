defmodule OliWeb.RegistrationController do
  use OliWeb, :controller

  alias Oli.Repo
  alias Oli.Institutions
  alias Oli.Lti_1p3.Tool.Registration
  alias OliWeb.Common.{Breadcrumb}

  def root_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "LTI 1.3 Registrations",
          link: Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.RegistrationsView)
        })
      ]
  end

  def breadcrumbs(action, name) do
    root_breadcrumbs() ++
      [
        Breadcrumb.new(%{
          full_title: name,
          link: Routes.registration_path(OliWeb.Endpoint, action)
        })
      ]
  end

  def breadcrumbs(action, id, name) do
    root_breadcrumbs() ++
      [
        Breadcrumb.new(%{
          full_title: name,
          link: Routes.registration_path(OliWeb.Endpoint, action, id)
        })
      ]
  end

  def index(conn, _params) do
    registrations = Institutions.list_registrations(preload: [:deployments])

    render(conn, "index.html",
      breadcrumbs: root_breadcrumbs(),
      registrations: registrations
    )
  end

  def new(conn, _params) do
    changeset = Institutions.change_registration(%Registration{})

    render(conn, "new.html",
      changeset: changeset,
      breadcrumbs: breadcrumbs(:create, "New"),
      title: "Create Registration"
    )
  end

  def create(conn, %{"registration" => registration_params}) do
    {:ok, active_jwk} = Lti_1p3.get_active_jwk()

    registration_params =
      registration_params
      |> Map.put("tool_jwk_id", active_jwk.id)

    case Institutions.create_registration(registration_params) do
      {:ok, registration} ->
        conn
        |> put_flash(:info, "Registration created successfully.")
        |> redirect(to: Routes.registration_path(conn, :show, registration.id))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html",
          changeset: changeset,
          breadcrumbs: breadcrumbs(:create, "New"),
          title: "Create Registration"
        )
    end
  end

  def show(conn, %{"id" => id}) do
    registration = Institutions.get_registration!(id) |> Repo.preload([:deployments])

    render(conn, "show.html",
      registration: registration,
      breadcrumbs: breadcrumbs(:show, id, "Show")
    )
  end

  def edit(conn, %{"id" => id}) do
    registration = Institutions.get_registration_preloaded!(id)
    changeset = Institutions.change_registration(registration)

    render(conn, "edit.html",
      registration: registration,
      breadcrumbs: breadcrumbs(:edit, id, "Edit"),
      changeset: changeset,
      title: "Edit Registration"
    )
  end

  def update(conn, %{
        "id" => id,
        "registration" => registration_params
      }) do
    registration = Institutions.get_registration!(id)

    case Institutions.update_registration(registration, registration_params) do
      {:ok, _registration} ->
        conn
        |> put_flash(:info, "Registration updated successfully.")
        |> redirect(to: Routes.registration_path(conn, :show, id))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html",
          breadcrumbs: breadcrumbs(:edit, id, "Edit"),
          registration: registration,
          changeset: changeset,
          title: "Edit Registration"
        )
    end
  end

  def delete(conn, %{"id" => id}) do
    registration = Institutions.get_registration!(id)
    {:ok, _registration} = Institutions.delete_registration(registration)

    conn
    |> put_flash(:info, "Registration deleted successfully.")
    |> redirect(to: Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.RegistrationsView))
  end
end
