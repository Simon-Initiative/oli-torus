defmodule OliWeb.RegistrationController do
  use OliWeb, :controller

  alias Oli.Institutions
  alias Oli.Lti_1p3.Tool.Registration
  alias Oli.Branding

  def available_brands(institution_id) do
    institution = Institutions.get_institution!(institution_id)
    available_brands = Branding.list_available_brands(institution_id)
    institution_brands = available_brands
      |> Enum.filter(fn b -> b.institution_id != nil end)
      |> Enum.map(fn brand -> {brand.name, brand.id} end)
    other_brands = available_brands
      |> Enum.filter(fn b -> b.institution_id == nil end)
      |> Enum.map(fn brand -> {brand.name, brand.id} end)

    []
    |> Enum.concat(if Enum.count(institution_brands) > 0, do: ["#{institution.name} Brands": institution_brands], else: [])
    |> Enum.concat(if Enum.count(other_brands) > 0, do: ["Other Brands": other_brands], else: [])
  end

  def new(conn, %{"institution_id" => institution_id}) do
    changeset = Institutions.change_registration(%Registration{institution_id: institution_id})

    render(conn, "new.html",
      changeset: changeset,
      institution_id: institution_id,
      available_brands: available_brands(institution_id),
      title: "Create Registration"
    )
  end

  def create(conn, %{"institution_id" => institution_id, "registration" => registration_params}) do
    {:ok, active_jwk} = Lti_1p3.get_active_jwk()

    registration_params =
      registration_params
      |> Map.put("institution_id", institution_id)
      |> Map.put("tool_jwk_id", active_jwk.id)

    case Institutions.create_registration(registration_params) do
      {:ok, _registration} ->
        conn
        |> put_flash(:info, "Registration created successfully.")
        |> redirect(to: Routes.institution_path(conn, :show, institution_id))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html",
          changeset: changeset,
          institution_id: institution_id,
          available_brands: available_brands(institution_id),
          title: "Create Registration"
        )
    end
  end

  def edit(conn, %{"institution_id" => institution_id, "id" => id}) do
    registration = Institutions.get_registration!(id)
    changeset = Institutions.change_registration(registration)

    render(conn, "edit.html",
      registration: registration,
      changeset: changeset,
      institution_id: institution_id,
      available_brands: available_brands(institution_id),
      title: "Edit Registration"
    )
  end

  def update(conn, %{
        "institution_id" => institution_id,
        "id" => id,
        "registration" => registration_params
      }) do
    registration = Institutions.get_registration!(id)

    case Institutions.update_registration(registration, registration_params) do
      {:ok, _registration} ->
        conn
        |> put_flash(:info, "Registration updated successfully.")
        |> redirect(to: Routes.institution_path(conn, :show, institution_id))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html",
          registration: registration,
          changeset: changeset,
          institution_id: institution_id,
          available_brands: available_brands(institution_id),
          title: "Edit Registration"
        )
    end
  end

  def delete(conn, %{"institution_id" => institution_id, "id" => id}) do
    registration = Institutions.get_registration!(id)
    {:ok, _registration} = Institutions.delete_registration(registration)

    conn
    |> put_flash(:info, "Registration deleted successfully.")
    |> redirect(to: Routes.institution_path(conn, :show, institution_id))
  end
end
