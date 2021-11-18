defmodule OliWeb.CommunityLive.ShowView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.Modal

  alias Oli.Groups
  alias OliWeb.Common.{Breadcrumb, DeleteModal}
  alias OliWeb.CommunityLive.Associated.IndexView, as: IndexAssociated
  alias Surface.Components.Link

  alias OliWeb.CommunityLive.{
    Form,
    IndexView,
    AccountInvitation,
    ShowSection
  }

  alias OliWeb.Router.Helpers, as: Routes

  data title, :string, default: "Edit Community"
  data community, :struct
  data changeset, :changeset
  data breadcrumbs, :list
  data modal, :any, default: nil
  data community_admins, :list
  data community_members, :list

  @delete_modal_description """
    This action will not affect existing course sections that are using this community.
    Those sections will continue to operate as intended.
  """

  def breadcrumb(community_id) do
    IndexView.breadcrumb() ++
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
          |> push_redirect(to: Routes.live_path(OliWeb.Endpoint, IndexView))

        community ->
          changeset = Groups.change_community(community)
          community_admins = Groups.list_community_admins(community_id)
          community_members = Groups.list_community_members(community_id)

          assign(socket,
            community: community,
            changeset: changeset,
            breadcrumbs: breadcrumb(community_id),
            community_admins: community_admins,
            community_id: community_id,
            community_members: community_members
          )
      end

    {:ok, socket}
  end

  def render(assigns) do
    ~F"""
      {render_modal(assigns)}
      <div id="community-overview" class="overview container">
        <ShowSection section_title="Details" section_description="Main community fields that will be shown to system admins and community admins.">
          <Form changeset={@changeset} save="save"/>
        </ShowSection>

        <ShowSection
          section_title="Community Admins"
          section_description="Add other authors by email to administrate the community."
        >
          <AccountInvitation
            invite="add_admin"
            remove="remove_admin"
            placeholder="admin@example.edu"
            button_text="Add"
            collaborators={@community_admins}/>
        </ShowSection>

        <ShowSection
          section_title="Community Members"
          section_description="Add users by email to be members of the community."
        >
          <AccountInvitation
            invite="add_member"
            remove="remove_member"
            placeholder="user@example.edu"
            button_text="Add"
            collaborators={@community_members}/>
        </ShowSection>

        <ShowSection
          section_title="Projects and Products"
          section_description="Make selected Projects and Products available to members of this Community."
        >
          <Link class="btn btn-link" to={Routes.live_path(@socket, IndexAssociated, @community_id)}>
            See associated
          </Link>
        </ShowSection>

        <ShowSection section_title="Actions">
          <div class="d-flex align-items-center">
            <button type="button" class="btn btn-link text-danger action-button" :on-click="show_delete_modal">Delete</button>
            <span>Permanently delete this community.</span>
          </div>
        </ShowSection>
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
          |> push_redirect(to: Routes.live_path(OliWeb.Endpoint, IndexView))

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
      component: DeleteModal,
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

  defp community_users_assigns("admin", community_id) do
    [community_admins: Groups.list_community_admins(community_id)]
  end

  defp community_users_assigns("member", community_id) do
    [community_members: Groups.list_community_members(community_id)]
  end

  defp community_users_assigns(_user_type, _community_id), do: []

  def handle_event("add_" <> user_type, %{"collaborator" => %{"email" => email}}, socket) do
    socket = clear_flash(socket)

    attrs = %{
      community_id: socket.assigns.community.id,
      is_admin: user_type == "admin"
    }

    case Groups.create_community_account_from_email(user_type, email, attrs) do
      {:ok, _community_account} ->
        socket = put_flash(socket, :info, "Community #{user_type} successfully added.")
        updated_assigns = community_users_assigns(user_type, attrs.community_id)

        {:noreply, assign(socket, updated_assigns)}

      {:error, error} ->
        message =
          case error do
            :author_not_found ->
              "Community admin couldn't be added. Author does not exist."

            :user_not_found ->
              "Community member couldn't be added. User does not exist."

            %Ecto.Changeset{} ->
              "Community user couldn't be added. It is already associated to the community or an unexpected error occurred."
          end

        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("remove_" <> user_type, %{"collaborator-id" => user_id}, socket) do
    socket = clear_flash(socket)

    attrs = %{
      community_id: socket.assigns.community.id
    }

    case user_type do
      "admin" -> %{author_id: user_id}
      "member" -> %{user_id: user_id}
    end
    |> Map.merge(attrs)
    |> Groups.delete_community_account()
    |> case do
      {:ok, _community_account} ->
        socket = put_flash(socket, :info, "Community #{user_type} successfully removed.")
        updated_assigns = community_users_assigns(user_type, attrs.community_id)

        {:noreply, assign(socket, updated_assigns)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Community #{user_type} couldn't be removed.")}
    end
  end
end
