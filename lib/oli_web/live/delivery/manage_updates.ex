defmodule OliWeb.Delivery.ManageUpdates do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  import OliWeb.ViewHelpers,
    only: [
      is_section_instructor_or_admin?: 2
    ]

  import OliWeb.Delivery.Updates.Utils

  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Delivery.Sections
  alias Oli.Publishing
  alias OliWeb.Delivery.Updates.ApplyUpdateModal

  def mount(
        _params,
        %{
          "section" => section,
          "redirect_after_apply" => redirect_after_apply,
          "current_user" => current_user,
          "current_author" => current_author
        },
        socket
      ) do
    if section.open_and_free do
      # only permit authoring admin level access
      if Accounts.is_admin?(current_author) do
        init_state(socket, section, redirect_after_apply)
      else
        {:ok, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :unauthorized))}
      end
    else
      # only permit instructor or admin level access
      current_user = current_user |> Repo.preload([:platform_roles, :author])

      if is_section_instructor_or_admin?(section.slug, current_user) do
        init_state(socket, section, redirect_after_apply)
      else
        {:ok, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :unauthorized))}
      end
    end
  end

  def init_state(socket, section, redirect_after_apply) do
    updates = Sections.check_for_available_publication_updates(section)

    socket =
      socket
      |> assign(:section, section)
      |> assign(:updates, updates)
      |> assign(:modal, nil)
      |> assign(:redirect_after_apply, redirect_after_apply)

    {:ok, socket}
  end

  def render(assigns) do
    %{
      updates: updates
    } = assigns

    ~L"""
      <%= render_modal(assigns) %>

      <p class="my-4">
        <%= case Enum.count(updates) do %>
            <% 0 -> %>
              There are <b>no updates</b> available for this section.
            <% 1 -> %>
              There is <b>one</b> update available for this section:

              <%= render_updates(assigns) %>
            <% num_updates -> %>
              There are <b><%= num_updates %></b> updates available for this section:

              <%= render_updates(assigns) %>
        <% end %>
      </p>
    """
  end

  # handle any cancel events a modal might generate from being closed
  def handle_event("cancel_modal", _params, socket),
    do:
      {:noreply,
       socket
       |> hide_modal()}

  def handle_event(
        "show_apply_update_modal",
        %{"project-id" => project_id, "publication-id" => publication_id},
        socket
      ) do
    %{section: section, updates: updates} = socket.assigns
    current_publication = Sections.get_current_publication(section.id, project_id)
    newest_publication = Publishing.get_publication!(publication_id)

    {_version_change, changes} =
      Publishing.diff_publications(current_publication, newest_publication)

    {:noreply,
     assign(socket,
       modal: %{
         component: ApplyUpdateModal,
         assigns: %{
           id: "apply_update_modal",
           current_publication: current_publication,
           newest_publication: newest_publication,
           project_id: String.to_integer(project_id),
           publication_id: String.to_integer(publication_id),
           changes: changes,
           updates: updates
         }
       }
     )}
  end

  def handle_event("apply_update", _, socket) do
    %{
      section: section,
      modal: %{assigns: %{project_id: project_id, publication_id: publication_id}},
      redirect_after_apply: redirect_after_apply
    } = socket.assigns

    publication = Publishing.get_publication!(publication_id)

    Repo.transaction(fn ->
      Sections.update_section_project_publication(section, project_id, publication_id)
      Sections.rebuild_section_resources(section: section, publication: publication)
    end)

    {:noreply,
     push_redirect(socket,
       to: redirect_after_apply
     )}
  end
end
