defmodule OliWeb.PublisherLive.ShowView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, :live}
  use OliWeb.Common.Modal

  import Ecto.Changeset
  import OliWeb.ErrorHelpers

  alias Oli.Inventories
  alias OliWeb.Common.{Breadcrumb, Confirm, DeleteModal, Params, ShowSection}

  alias OliWeb.PublisherLive.{
    Form,
    IndexView
  }

  alias OliWeb.Router.Helpers, as: Routes

  alias Surface.Components.Form, as: SurfaceForm

  alias Surface.Components.Form.{
    Field,
    Label,
    Checkbox
  }

  data(title, :string, default: "Edit Publisher")
  data(publisher, :struct)
  data(changeset, :changeset)
  data(breadcrumbs, :list)
  data(modal, :any, default: nil)
  data(show_confirm_default, :boolean, default: false)

  def breadcrumb(publisher_id) do
    IndexView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "Overview",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, publisher_id)
        })
      ]
  end

  def mount(%{"publisher_id" => publisher_id}, _session, socket) do
    socket =
      case Inventories.get_publisher(publisher_id) do
        nil ->
          socket
          |> put_flash(:info, "That publisher does not exist or it was deleted.")
          |> push_redirect(to: Routes.live_path(OliWeb.Endpoint, IndexView))

        publisher ->
          changeset = Inventories.change_publisher(publisher)

          assign(socket,
            publisher: publisher,
            changeset: changeset,
            breadcrumbs: breadcrumb(publisher_id)
          )
      end

    {:ok, socket}
  end

  def render(assigns) do
    ~F"""
      {render_modal(assigns)}
      <div id="publisher-overview" class="overview container">
        <ShowSection.render
          section_title="Details"
          section_description="Main publisher fields that will be shown to system admins."
        >
          <Form.render changeset={@changeset} save="save"/>
        </ShowSection.render>

        <ShowSection.render section_title="Actions">
          <div>
            <SurfaceForm for={@changeset} change="save" class="d-flex">
              <div class="form-group">
                <div class="form-row">
                  <div class="custom-control custom-switch">
                    <Field name={:available_via_api} class="form-check">
                      <Checkbox class="custom-control-input" value={get_field(@changeset, :available_via_api)}/>
                      <Label class="custom-control-label">Available via API</Label>
                      <p class="text-muted">Make the publisher available through the publishers API</p>
                    </Field>
                  </div>
                </div>
              </div>
            </SurfaceForm>
            {#unless @publisher.default}
              <div class="d-flex align-items-center">
                <button type="button" class="btn btn-link text-danger action-button" :on-click="show_delete_modal">Delete</button>
                <span>Permanently delete this publisher.</span>
              </div>
              <div class="d-flex align-items-center">
                <button type="button" class="btn btn-link action-button" :on-click="show_set_default_modal">Set this publisher as the default</button>
              </div>
            {/unless}
          </div>
        </ShowSection.render>
      </div>
      {#if @show_confirm_default}
        <Confirm.render title="Confirm Default" id="set_default_modal" ok="set_default" cancel="cancel_set_default_modal">
          Are you sure that you wish to set this publisher as the default?
        </Confirm.render>
      {/if}
    """
  end

  def handle_event("save", %{"publisher" => params}, socket) do
    socket = clear_flash(socket)

    case Inventories.update_publisher(socket.assigns.publisher, Params.trim(params)) do
      {:ok, publisher} ->
        socket = put_flash(socket, :info, "Publisher successfully updated.")

        {:noreply,
         assign(socket, publisher: publisher, changeset: Inventories.change_publisher(publisher))}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          put_flash(
            socket,
            :error,
            "Publisher couldn't be updated. Please check the errors below."
          )

        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("delete", _params, socket) do
    socket = clear_flash(socket)

    socket =
      case Inventories.delete_publisher(socket.assigns.publisher) do
        {:ok, _publisher} ->
          socket
          |> put_flash(:info, "Publisher successfully deleted.")
          |> push_redirect(to: Routes.live_path(OliWeb.Endpoint, IndexView))

        {:error, %Ecto.Changeset{} = changeset} ->
          put_flash(
            socket,
            :error,
            "Publisher couldn't be deleted: #{translate_all_changeset_errors(changeset)}."
          )
      end

    {:noreply, socket |> hide_modal(modal_assigns: nil)}
  end

  def handle_event("validate_name_for_deletion", %{"publisher" => %{"name" => name}}, socket) do
    delete_enabled = name == socket.assigns.publisher.name
    %{modal_assigns: modal_assigns} = socket.assigns

    modal_assigns = %{
      modal_assigns
      | delete_enabled: delete_enabled
    }

    {:noreply, assign(socket, modal_assigns: modal_assigns)}
  end

  def handle_event("show_delete_modal", _, socket) do
    modal_assigns = %{
      id: "delete_publisher_modal",
      description: "",
      entity_name: socket.assigns.publisher.name,
      entity_type: "publisher",
      delete_enabled: false,
      validate: "validate_name_for_deletion",
      delete: "delete"
    }

    modal = fn assigns ->
      ~F"""
        <DeleteModal {...@modal_assigns} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event("show_set_default_modal", _, socket) do
    {:noreply, assign(socket, show_confirm_default: true)}
  end

  def handle_event("cancel_set_default_modal", _, socket) do
    {:noreply, assign(socket, show_confirm_default: false)}
  end

  def handle_event("set_default", _, socket) do
    socket = assign(socket, show_confirm_default: false)

    case Inventories.set_default_publisher(socket.assigns.publisher) do
      {:ok, default} ->
        socket = put_flash(socket, :info, "Publisher successfully set as the default.")

        {:noreply,
         assign(socket, publisher: default, changeset: Inventories.change_publisher(default))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Could not update default publisher: #{translate_all_changeset_errors(changeset)}"
         )}
    end
  end
end
