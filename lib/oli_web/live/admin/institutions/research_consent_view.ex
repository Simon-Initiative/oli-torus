defmodule OliWeb.Admin.Institutions.ResearchConsentView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, :live}

  alias Oli.Institutions
  alias Oli.Institutions.Institution
  alias OliWeb.Common.{Breadcrumb, FormContainer}
  alias OliWeb.InstitutionController
  alias OliWeb.Router.Helpers, as: Routes
  alias Surface.Components.Form
  alias Surface.Components.Form.{ErrorTag, Field, RadioButton}

  data breadcrumbs, :any
  data title, :string, default: "Manage Research Consent"
  data institution, :any, default: nil
  data changeset, :changeset, default: nil

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

  def render(assigns) do
    ~F"""
      <FormContainer title={@title}>
        <Form for={@changeset} submit="save">
          <Field name={:research_consent} class="form-group">
            <div class="form-check p-2">
              <div class="p-2">
                <RadioButton value={:oli_form} />
                <label class="form-check-label ml-1">OLI Research Consent Form</label><br>
              </div>
              <div class="p-2">
                <RadioButton value={:no_form} />
                <label class="form-check-label ml-1">No Research Consent Form</label>
              </div>
            </div>
            <ErrorTag/>
          </Field>

          <button class="form-button btn btn-md btn-primary btn-block mt-3" type="submit">Save</button>
        </Form>
      </FormContainer>
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
