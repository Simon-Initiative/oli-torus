defmodule OliWeb.CommunityLive.Show do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.Modal

  alias Oli.Groups
  alias OliWeb.Common.{Breadcrumb, DeleteModalComponent}

  alias OliWeb.CommunityLive.{
    FormComponent,
    Index,
    AccountInvitationComponent,
    ShowSectionComponent
  }

  alias OliWeb.Router.Helpers, as: Routes

  data title, :string, default: "Edit Community"
  data community, :struct
  data changeset, :changeset
  data breadcrumbs, :list
  data modal, :any, default: nil
  data community_admins, :list

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
          community_admins = Groups.list_community_admins(community_id)

          assign(socket,
            community: community,
            changeset: changeset,
            breadcrumbs: breadcrumb(community_id),
            community_admins: community_admins
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

        <ShowSectionComponent
          section_title="Community Admins"
          section_description="Add other authors by email to administrate the community."
        >
          <AccountInvitationComponent
            invite="add_collaborator"
            remove="remove_collaborator"
            placeholder="admin@example.edu"
            button_text="Add"
            collaborators={@community_admins}/>
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

  def handle_event("add_collaborator", %{"collaborator" => %{"email" => email}}, socket) do
    socket = clear_flash(socket)

    attrs = %{
      community_id: socket.assigns.community.id,
      is_admin: true
    }

    case Groups.create_community_account_from_author_email(email, attrs) do
      {:ok, _community_account} ->
        socket = put_flash(socket, :info, "Admin successfully added.")
        community_admins = Groups.list_community_admins(attrs.community_id)

        {:noreply, assign(socket, community_admins: community_admins)}

      {:error, error} ->
        message =
          case error do
            :author_not_found ->
              "Community admin couldn't be added. Author does not exist."

            %Ecto.Changeset{} ->
              "Community admin couldn't be added. Author is already an admin or an unexpected error occurred."
          end

        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("remove_collaborator", %{"collaborator-id" => admin_id}, socket) do
    socket = clear_flash(socket)

    attrs = %{
      community_id: socket.assigns.community.id,
      author_id: admin_id
    }

    case Groups.delete_community_account(attrs) do
      {:ok, _community_account} ->
        socket = put_flash(socket, :info, "Admin successfully removed.")
        community_admins = Groups.list_community_admins(attrs.community_id)

        {:noreply, assign(socket, community_admins: community_admins)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Community admin couldn't be removed.")}
    end
  end
end
