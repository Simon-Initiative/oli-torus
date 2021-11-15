defmodule OliWeb.CommunityLive.Show do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.Modal

  alias Oli.Groups
  alias Oli.Groups.Community
  alias OliWeb.Common.{Breadcrumb, DeleteModalComponent}
  alias OliWeb.CommunityLive.{FormComponent, Index, ShowSectionComponent}
  alias OliWeb.Router.Helpers, as: Routes

  data title, :string, default: "Edit Community"
  data community, :struct
  data changeset, :changeset
  data breadcrumbs, :list
  data modal, :any, default: nil

  @delete_modal_description """
    This action will not affect existing course sections that are using this community.
    Those sections will continue to operate as intended.
  """

  def breadcrumb(community_id) do
    Index.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "Overview",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, community_id)
        })
      ]
  end

  def mount(%{"community_id" => community_id}, _session, socket) do
    socket =
      case Groups.get_community(community_id) do
        nil ->
          socket
          |> put_flash(:info, "That community does not exist or it was deleted.")
          |> push_redirect(to: Routes.live_path(OliWeb.Endpoint, Index))

        community ->
          changeset = Groups.change_community(community)

          assign(socket,
            community: community,
            changeset: changeset,
            breadcrumbs: breadcrumb(community_id)
          )
      end

    {:ok, socket}
  end

  def render(assigns) do
    ~F"""
      {render_modal(assigns)}
      <div id="community-overview" class="overview container">
        <ShowSectionComponent section_title="Details" section_description="Main community fields that will be shown to system admins and community admins.">
          <FormComponent changeset={@changeset} save="save"/>
        </ShowSectionComponent>
        <ShowSectionComponent section_title="Actions">
          <div class="d-flex align-items-center">
            <button type="button" class="btn btn-link text-danger action-button" :on-click="show_delete_modal">Delete</button>
            <span>Permanently delete this community.</span>
          </div>
        </ShowSectionComponent>
      </div>
    """
  end

  def handle_event("save", %{"community" => params}, socket) do
    case Groups.update_community(socket.assigns.community, params) do
      {:ok, community} ->
        socket = put_flash(socket, :info, "Community successfully updated.")

        {:noreply,
         assign(socket, community: community, changeset: Groups.change_community(community))}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          put_flash(
            socket,
            :error,
            "Community couldn't be updated. Please check the errors below."
          )

        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("delete", _params, socket) do
    socket =
      case Groups.delete_community(socket.assigns.community) do
        {:ok, _community} ->
          socket
          |> put_flash(:info, "Community successfully deleted.")
          |> push_redirect(to: Routes.live_path(OliWeb.Endpoint, Index))

        {:error, %Ecto.Changeset{}} ->
          put_flash(
            socket,
            :error,
            "Community couldn't be deleted."
          )
      end

    {:noreply, socket |> hide_modal()}
  end

  def handle_event("validate_name_for_deletion", %{"community" => %{"name" => name}}, socket) do
    delete_enabled = name == socket.assigns.community.name
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
      component: DeleteModalComponent,
      assigns: %{
        id: "delete_community_modal",
        description: @delete_modal_description,
        entity_name: socket.assigns.community.name,
        entity_type: "community",
        delete_enabled: false,
        validate: "validate_name_for_deletion",
        delete: "delete"
      }
    }

    {:noreply, assign(socket, modal: modal)}
  end
end
