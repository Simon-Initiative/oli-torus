defmodule OliWeb.Admin.Institutions.ResearchConsentView do
  use OliWeb, :live_view

  alias Oli.Institutions
  alias Oli.Institutions.Institution
  alias OliWeb.Common.{Breadcrumb, FormContainer}
  alias OliWeb.InstitutionController
  alias OliWeb.Router.Helpers, as: Routes

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  defp institution_route(institution_id),
    do: Routes.institution_path(OliWeb.Endpoint, :show, institution_id)

  defp set_breadcrumbs(institution) do
    InstitutionController.root_breadcrumbs() ++
      [
        Breadcrumb.new(%{
          full_title: "#{institution.name}",
          link: institution_route(institution.id)
        })
      ] ++ [Breadcrumb.new(%{full_title: "Manage Research Consent"})]
  end

  def mount(%{"institution_id" => institution_id}, _session, socket) do
    case Institutions.get_institution_by!(%{id: institution_id}) do
      %Institution{} = institution ->
        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(institution),
           institution: institution,
           changeset: Institutions.change_institution(institution)
         )}

      _ ->
        {:ok,
         Phoenix.LiveView.redirect(socket,
           to: Routes.static_page_path(OliWeb.Endpoint, :not_found)
         )}
    end
  end

  attr :breadcrumbs, :any
  attr :title, :string, default: "Manage Research Consent"
  attr :institution, :any, default: nil
  attr :changeset, :map, default: nil

  def render(assigns) do
    ~H"""
    <FormContainer.render title={@title}>
      <.form for={@changeset} phx-submit="save">
        <div class="form-check p-2">
          <div class="p-2">
            <input
              id="research_consent_yes"
              checked={Ecto.Changeset.get_field(@changeset, :research_consent) == :oli_form}
              name="institution[research_consent]"
              type="radio"
              value={:oli_form}
            />
            <label for="research_consent_yes" class="form-check-label ml-1">
              OLI Research Consent Form
            </label>
            <br />
          </div>
          <div class="p-2">
            <input
              id="research_consent_no"
              checked={Ecto.Changeset.get_field(@changeset, :research_consent) == :no_form}
              name="institution[research_consent]"
              type="radio"
              value={:no_form}
            />
            <label for="research_consent_no" class="form-check-label ml-1">
              No Research Consent Form
            </label>
          </div>
          <.error :for={error <- Keyword.get_values(@changeset.errors || [], :research_consent)}>
            <%= translate_error(error) %>
          </.error>
        </div>

        <button class="form-button btn btn-md btn-primary btn-block mt-3" type="submit">Save</button>
      </.form>
    </FormContainer.render>
    """
  end

  def handle_event("save", %{"institution" => params}, socket) do
    socket = clear_flash(socket)

    case Institutions.update_institution(socket.assigns.institution, params) do
      {:ok, %Institution{id: institution_id}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Institution successfully updated.")
         |> redirect(to: institution_route(institution_id))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Institution couldn't be created/updated. Please check the errors below."
         )
         |> assign(changeset: changeset)}
    end
  end
end
