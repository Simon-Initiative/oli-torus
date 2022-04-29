defmodule OliWeb.PublisherLive.ShowView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.Modal

  alias Oli.Inventories
  alias OliWeb.Common.{Breadcrumb, DeleteModal, Params, ShowSection}

  alias OliWeb.PublisherLive.{
    Form,
    IndexView
  }

  alias OliWeb.Router.Helpers, as: Routes

  data title, :string, default: "Edit Publisher"
  data publisher, :struct
  data changeset, :changeset
  data breadcrumbs, :list
  data modal, :any, default: nil
  data is_default_publisher, :boolean, default: false

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

          is_default_publisher = publisher.name == Inventories.default_publisher_name()

          assign(socket,
            publisher: publisher,
            changeset: changeset,
            breadcrumbs: breadcrumb(publisher_id),
            is_default_publisher: is_default_publisher
          )
      end

    {:ok, socket}
  end

  def render(assigns) do
    ~F"""
      {render_modal(assigns)}
      <div id="publisher-overview" class="overview container">
        <ShowSection
          section_title="Details"
          section_description="Main publisher fields that will be shown to system admins."
        >
          <Form changeset={@changeset} is_default_publisher={@is_default_publisher} save="save"/>
        </ShowSection>

        <ShowSection section_title="Actions">
          <div class="d-flex align-items-center">
            <button type="button" class="btn btn-link text-danger action-button" :on-click="show_delete_modal" disabled={@is_default_publisher}>Delete</button>
            <span>Permanently delete this publisher.</span>
          </div>
        </ShowSection>
      </div>
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

        {:error, %Ecto.Changeset{}} ->
          put_flash(
            socket,
            :error,
            "Publisher couldn't be deleted."
          )
      end

    {:noreply, socket |> hide_modal()}
  end

  def handle_event("validate_name_for_deletion", %{"publisher" => %{"name" => name}}, socket) do
    delete_enabled = name == socket.assigns.publisher.name
    %{modal: modal} = socket.assigns

    modal = %{
      modal
      | assigns: %{
          modal.assigns
          | delete_enabled: delete_enabled
        }
    }

    {:noreply, assign(socket, modal: modal)}
  end

  def handle_event("show_delete_modal", _, socket) do
    modal = %{
      component: DeleteModal,
      assigns: %{
        id: "delete_publisher_modal",
        description: "",
        entity_name: socket.assigns.publisher.name,
        entity_type: "publisher",
        delete_enabled: false,
        validate: "validate_name_for_deletion",
        delete: "delete"
      }
    }

    {:noreply, assign(socket, modal: modal)}
  end
end
