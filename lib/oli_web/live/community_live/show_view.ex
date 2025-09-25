defmodule OliWeb.CommunityLive.ShowView do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  alias Oli.Accounts
  alias Oli.Accounts.{AuthorBrowseOptions, UserBrowseOptions}
  alias Oli.Groups
  alias Oli.Institutions
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{Breadcrumb, DeleteModal, Params, ShowSection}
  alias OliWeb.CommunityLive.Associated.IndexView, as: IndexAssociated

  alias OliWeb.CommunityLive.{
    Form,
    IndexView,
    Invitation,
    MembersIndexView,
    SelectMemberModal
  }

  alias OliWeb.Router.Helpers, as: Routes

  @matches_limit 30

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}

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
          |> push_navigate(to: Routes.live_path(OliWeb.Endpoint, IndexView))

        community ->
          changeset = Groups.change_community(community)
          community_admins = Groups.list_community_admins(community_id)
          community_members = Groups.list_community_members(community_id, 3)
          community_institutions = Groups.list_community_institutions(community_id)

          available_institutions =
            Institutions.list_institutions()
            |> Enum.sort_by(& &1.name)

          assign(socket,
            community: community,
            form: to_form(changeset),
            breadcrumbs: breadcrumb(community_id),
            community_admins: community_admins,
            community_id: community_id,
            community_members: community_members,
            community_institutions: community_institutions,
            matches: %{"admin" => [], "member" => [], "institution" => []},
            available_institutions: available_institutions
          )
      end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div id="community-overview" class="overview container">
      {render_modal(assigns)}
      <ShowSection.render
        section_title="Details"
        section_description="Main community fields that will be shown to system admins and community admins."
      >
        <Form.render form={@form} save="save" />
      </ShowSection.render>

      <ShowSection.render
        section_title="Community Admins"
        section_description="Add other authors by email to administrate the community."
      >
        <Invitation.render
          to_invite={:admin}
          list_id="admin_matches"
          invite="add_admin"
          remove="remove_admin"
          suggest="suggest_admin"
          matches={@matches["admin"]}
          placeholder="admin@example.edu"
          button_text="Add"
          collaborators={@community_admins}
          allow_removal={Accounts.has_admin_role?(@current_author, :content_admin)}
        />
      </ShowSection.render>

      <ShowSection.render
        section_title="Community Members"
        section_description="Add users by email as members of the community (one at a time). Only showing the last 3 additions here."
      >
        <Invitation.render
          list_id="member_matches"
          invite="add_member"
          remove="remove_member"
          suggest="suggest_member"
          matches={@matches["member"]}
          placeholder="user@example.edu"
          button_text="Add"
          collaborators={@community_members}
        />

        <.link
          class="btn btn-link float-right mt-4"
          href={Routes.live_path(@socket, MembersIndexView, @community.id)}
        >
          See all
        </.link>
      </ShowSection.render>

      <ShowSection.render
        section_title="Projects and Products"
        section_description="Make selected Projects and Products available to members of this Community."
      >
        <.link class="btn btn-link" href={Routes.live_path(@socket, IndexAssociated, @community_id)}>
          See associated
        </.link>
      </ShowSection.render>

      <ShowSection.render
        section_title="Institutions"
        section_description="Add institutions to be part of the community."
      >
        <Invitation.render
          list_id="institution_matches"
          to_invite={:institution}
          search_field={:name}
          invite="add_institution"
          remove="remove_institution"
          matches={@matches["institution"]}
          main_fields={[primary: :name, secondary: :institution_email]}
          placeholder="Institution name"
          button_text="Add"
          collaborators={@community_institutions}
          available_institutions={@available_institutions}
        />
      </ShowSection.render>

      <ShowSection.render section_title="Actions">
        <div class="d-flex align-items-center">
          <button
            type="button"
            class="btn btn-link text-danger action-button"
            phx-click="show_delete_modal"
          >
            Delete
          </button>
          <span>Permanently delete this community.</span>
        </div>
      </ShowSection.render>
    </div>
    """
  end

  def handle_event("save", %{"community" => params}, socket) do
    socket = clear_flash(socket)

    case Groups.update_community(socket.assigns.community, Params.trim(params)) do
      {:ok, community} ->
        socket = put_flash(socket, :info, "Community successfully updated.")

        {:noreply,
         assign(socket, community: community, form: to_form(Groups.change_community(community)))}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          put_flash(
            socket,
            :error,
            "Community couldn't be updated. Please check the errors below."
          )

        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("delete", _params, socket) do
    socket = clear_flash(socket)

    socket =
      case Groups.delete_community(socket.assigns.community) do
        {:ok, _community} ->
          socket
          |> put_flash(:info, "Community successfully deleted.")
          |> push_navigate(to: Routes.live_path(OliWeb.Endpoint, IndexView))

        {:error, %Ecto.Changeset{}} ->
          put_flash(
            socket,
            :error,
            "Community couldn't be deleted."
          )
      end

    {:noreply, hide_modal(socket, modal_assigns: nil)}
  end

  def handle_event("validate_name_for_deletion", %{"name" => name}, socket) do
    delete_enabled = name == socket.assigns.community.name

    {:noreply,
     assign(socket,
       modal_assigns: %{
         socket.assigns.modal_assigns
         | delete_enabled: delete_enabled
       }
     )}
  end

  def handle_event("show_delete_modal", _, socket) do
    delete_modal_description = """
      This action will not affect existing course sections that are using this community.
      Those sections will continue to operate as intended.
    """

    modal_assigns = %{
      id: "delete_community_modal",
      description: delete_modal_description,
      entity_name: socket.assigns.community.name,
      entity_type: "community",
      delete_enabled: false,
      validate: "validate_name_for_deletion",
      delete: "delete"
    }

    modal = fn assigns ->
      ~H"""
      <DeleteModal.render {@modal_assigns} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event("add_admin", %{"email" => email}, socket) do
    socket = clear_flash(socket)
    current_author = socket.assigns.current_author

    attrs = %{
      community_id: socket.assigns.community.id,
      is_admin: Accounts.has_admin_role?(current_author, :account_admin)
    }

    emails =
      email
      |> String.split(",")
      |> Enum.map(&String.trim(&1))

    socket =
      case Groups.create_community_accounts_from_emails("admin", emails, attrs) do
        {:ok, _community_accounts} ->
          updated_assigns = community_accounts_assigns("admin", attrs.community_id)

          socket
          |> put_flash(:info, "Community admin(s) successfully added.")
          |> assign(updated_assigns)

        {:error, _error} ->
          message =
            "Some of the community admin(s) couldn't be added because the author(s) don't exist in the system or are already associated."

          put_flash(socket, :error, message)
      end

    {:noreply, socket}
  end

  def handle_event("add_member", %{"collaborator-id" => collaborator_id}, socket) do
    socket = clear_flash(socket)

    attrs = %{community_id: socket.assigns.community.id}

    socket =
      case Groups.create_community_account_from_user_id(collaborator_id, attrs) do
        {:ok, _community_account} ->
          updated_assigns = community_accounts_assigns("member", attrs.community_id)

          socket
          |> put_flash(:info, "Community member successfully added.")
          |> assign(updated_assigns)
          |> hide_modal(modal_assigns: nil)

        {:error, _error} ->
          message =
            "Member couldn't be added because the user don't exist in the system or is already associated."

          socket
          |> put_flash(:error, message)
          |> hide_modal(modal_assigns: nil)
      end

    {:noreply, socket}
  end

  def handle_event("add_member", %{"email" => email}, socket) do
    socket = clear_flash(socket)

    attrs = %{community_id: socket.assigns.community.id}
    matches = Map.get(socket.assigns.matches, "member")

    socket =
      if length(matches) > 1 do
        modal_assigns = %{
          id: "select_member_community_modal",
          members: matches,
          select: "add_member"
        }

        modal = fn assigns ->
          ~H"""
          <SelectMemberModal.render {@modal_assigns} />
          """
        end

        show_modal(socket, modal, modal_assigns: modal_assigns)
      else
        case Groups.create_community_account_from_email("member", String.trim(email), attrs) do
          {:ok, _community_account} ->
            updated_assigns = community_accounts_assigns("member", attrs.community_id)

            socket
            |> put_flash(:info, "Community member successfully added.")
            |> assign(updated_assigns)

          {:error, _error} ->
            message =
              "Member couldn't be added because the user don't exist in the system or is already associated."

            put_flash(socket, :error, message)
        end
      end

    {:noreply, socket}
  end

  def handle_event(
        "add_institution",
        %{"institution_id" => ""},
        socket
      ) do
    socket = clear_flash(socket)
    socket = put_flash(socket, :error, "Please select an institution.")
    {:noreply, socket}
  end

  def handle_event(
        "add_institution",
        %{"institution_id" => institution_id},
        socket
      ) do
    socket = clear_flash(socket)
    community_id = socket.assigns.community.id
    institution_id = String.to_integer(institution_id)

    institutions_added = socket.assigns.community_institutions |> Enum.map(& &1.id)

    if institution_id in institutions_added do
      socket = put_flash(socket, :error, "Institution has already been added to the community.")
      {:noreply, socket}
    else
      socket =
        case Groups.create_community_institutions_from_ids([institution_id], %{
               community_id: community_id
             }) do
          {:ok, _community_institutions} ->
            put_flash(socket, :info, "Community institution(s) successfully added.")

          {:error, _error} ->
            message =
              "Some of the community institutions couldn't be added because the institutions don't exist in the system or are already associated."

            put_flash(socket, :error, message)
        end

      {:noreply,
       assign(socket,
         community_institutions: Groups.list_community_institutions(community_id)
       )}
    end
  end

  def handle_event("remove_institution", %{"collaborator-id" => institution_id}, socket) do
    socket = clear_flash(socket)
    community_id = socket.assigns.community.id

    attrs = %{
      community_id: community_id,
      institution_id: institution_id
    }

    case Groups.delete_community_institution(attrs) do
      {:ok, _community_institution} ->
        socket = put_flash(socket, :info, "Community institution successfully removed.")

        {:noreply,
         assign(socket, community_institutions: Groups.list_community_institutions(community_id))}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Community institution couldn't be removed.")}
    end
  end

  def handle_event("remove_" <> user_type, %{"collaborator-id" => user_id}, socket) do
    socket = clear_flash(socket)

    attrs =
      Map.merge(
        %{
          community_id: socket.assigns.community.id
        },
        case user_type do
          "admin" -> %{author_id: user_id}
          "member" -> %{user_id: user_id}
        end
      )

    case Groups.delete_community_account(attrs) do
      {:ok, _community_account} ->
        socket = put_flash(socket, :info, "Community #{user_type} successfully removed.")
        updated_assigns = community_accounts_assigns(user_type, attrs.community_id)

        {:noreply, assign(socket, updated_assigns)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Community #{user_type} couldn't be removed.")}
    end
  end

  def handle_event("suggest_admin", %{"email" => query}, socket) do
    do_suggest("admin", query, socket)
  end

  def handle_event("suggest_member", %{"email" => query}, socket) do
    do_suggest("member", query, socket)
  end

  def handle_event("suggest_institution", %{"name" => query}, socket) do
    matches =
      Map.put(
        socket.assigns.matches,
        "institution",
        Institutions.search_institutions_matching(query)
      )

    {:noreply, assign(socket, matches: matches)}
  end

  defp do_suggest(user_type, query, socket) do
    matches = Map.put(socket.assigns.matches, user_type, browse_accounts(user_type, query))
    {:noreply, assign(socket, matches: matches)}
  end

  defp community_accounts_assigns("admin", community_id),
    do: [community_admins: Groups.list_community_admins(community_id)]

  defp community_accounts_assigns("member", community_id),
    do: [community_members: Groups.list_community_members(community_id, 3)]

  defp community_accounts_assigns(_user_type, _community_id), do: []

  defp browse_accounts("member", query),
    do:
      Accounts.browse_users(
        %Paging{offset: 0, limit: @matches_limit},
        %Sorting{direction: :asc, field: :name},
        %UserBrowseOptions{
          include_guests: false,
          text_search: query
        }
      )

  defp browse_accounts("admin", query),
    do:
      Accounts.browse_authors(
        %Paging{offset: 0, limit: @matches_limit},
        %Sorting{direction: :asc, field: :name},
        %AuthorBrowseOptions{
          text_search: query
        }
      )
end
