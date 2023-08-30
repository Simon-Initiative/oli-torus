defmodule OliWeb.InstitutionController do
  use OliWeb, :controller
  use OliWeb, :verified_routes

  alias Oli.Institutions
  alias Oli.Institutions.Institution
  alias Oli.Predefined
  alias OliWeb.Common.Breadcrumb
  alias Oli.Branding

  require Logger

  def root_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "Institutions",
          link: ~p"/admin/institutions"
        })
      ]
  end

  def named(previous, name) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: name
        })
      ]
  end

  defp available_brands(institution_id) do
    institution = Institutions.get_institution!(institution_id)

    institution_brands =
      Branding.list_available_brands(institution_id)
      |> Enum.map(fn brand -> {brand.name, brand.id} end)

    other_brands =
      Branding.list_available_brands()
      |> Enum.map(fn brand -> {brand.name, brand.id} end)

    []
    |> Enum.concat(
      if Enum.count(institution_brands) > 0,
        do: ["#{institution.name} Brands": institution_brands],
        else: []
    )
    |> Enum.concat(if Enum.count(other_brands) > 0, do: ["Other Brands": other_brands], else: [])
  end

  defp available_brands() do
    Branding.list_available_brands()
    |> Enum.map(fn brand -> {brand.name, brand.id} end)
  end

  def new(conn, _params) do
    changeset = Institutions.change_institution(%Institution{})

    render_institution_page(conn, "new.html",
      changeset: changeset,
      country_codes: Predefined.country_codes(),
      breadcrumbs: root_breadcrumbs() |> named("New"),
      available_brands: available_brands()
    )
  end

  def create(conn, %{"institution" => institution_params}) do
    author_id = conn.assigns.current_author.id

    institution_params =
      institution_params
      |> Map.put("author_id", author_id)

    case Institutions.create_institution(institution_params) do
      {:ok, _institution} ->
        conn
        |> put_flash(:info, "Institution created")
        |> redirect(to: ~p"/admin/institutions")

      {:error, %Ecto.Changeset{} = changeset} ->
        render_institution_page(conn, "new.html",
          changeset: changeset,
          country_codes: Predefined.country_codes(),
          breadcrumbs: root_breadcrumbs() |> named("New"),
          available_brands: available_brands()
        )
    end
  end

  def show(conn, %{"id" => id}) do
    institution = Institutions.get_institution!(id)

    render_institution_page(conn, "show.html",
      institution: institution,
      breadcrumbs: root_breadcrumbs() |> named("Details")
    )
  end

  def edit(conn, %{"id" => id}) do
    institution = Institutions.get_institution!(id)
    changeset = Institutions.change_institution(institution)

    render_institution_page(conn, "edit.html",
      breadcrumbs: root_breadcrumbs() |> named("Edit"),
      institution: institution,
      changeset: changeset,
      country_codes: Predefined.country_codes(),
      available_brands: available_brands(id)
    )
  end

  def update(conn, %{"id" => id, "institution" => institution_params}) do
    institution = Institutions.get_institution!(id)

    case Institutions.update_institution(institution, institution_params) do
      {:ok, institution} ->
        conn
        |> put_flash(:info, "Institution updated")
        |> redirect(to: Routes.institution_path(conn, :show, institution))

      {:error, %Ecto.Changeset{} = changeset} ->
        render_institution_page(conn, "edit.html",
          breadcrumbs: root_breadcrumbs() |> named("Edit"),
          institution: institution,
          changeset: changeset,
          country_codes: Predefined.country_codes(),
          available_brands: available_brands(id)
        )
    end
  end

  def delete(conn, %{"id" => id}) do
    cond do
      Institutions.institution_has_deployments?(id) ->
        conn
        |> put_flash(
          :error,
          "Institution with deployments cannot be deleted. Please move or delete all associated deployments and try again"
        )
        |> redirect(to: Routes.institution_path(conn, :show, id))

      Institutions.institution_has_communities?(id) ->
        conn
        |> put_flash(
          :error,
          "Institution with communities cannot be deleted. Please move or delete all associated communities and try again"
        )
        |> redirect(to: Routes.institution_path(conn, :show, id))

      true ->
        institution = Institutions.get_institution!(id)
        {:ok, _institution} = Institutions.update_institution(institution, %{status: :deleted})

        conn
        |> put_flash(:info, "Institution deleted")
        |> redirect(to: ~p"/admin/institutions")
    end
  end

  defp render_institution_page(conn, template, assigns) do
    render(conn, template, Keyword.merge(assigns, active: :institutions, title: "Institutions"))
  end
end
