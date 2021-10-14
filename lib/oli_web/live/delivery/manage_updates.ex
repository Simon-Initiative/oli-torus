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
  alias Oli.Delivery.Updates.Worker
  alias OliWeb.Delivery.Updates.ApplyUpdateModal
  alias Oli.Delivery.Updates.Subscriber

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

  def mount(
        %{
          "section_slug" => product_slug
        },
        %{
          "current_author_id" => current_author_id
        },
        socket
      ) do
    if Oli.Delivery.Sections.Blueprint.is_author_of_blueprint?(product_slug, current_author_id) do
      init_state(
        socket,
        Sections.get_section_by(slug: product_slug),
        Routes.live_path(socket, OliWeb.Products.DetailsView, product_slug)
      )
    else
      {:ok, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :unauthorized))}
    end
  end

  def init_state(socket, section, redirect_after_apply) do
    updates = Sections.check_for_available_publication_updates(section)
    updates_in_progress = Sections.check_for_updates_in_progress(section)

    Subscriber.subscribe_to_update_progress(section.id)

    socket =
      socket
      |> assign(:title, "Manage Updates")
      |> assign(:section, section)
      |> assign(:updates, updates)
      |> assign(:modal, nil)
      |> assign(:redirect_after_apply, redirect_after_apply)
      |> assign(:updates_in_progress, updates_in_progress)

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

  def handle_event(
        "show_apply_update_modal",
        %{"project-id" => project_id, "publication-id" => publication_id},
        socket
      ) do
    %{section: section, updates: updates, updates_in_progress: updates_in_progress} =
      socket.assigns

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
      modal: %{assigns: %{publication_id: publication_id}},
      updates_in_progress: updates_in_progress
    } = socket.assigns

    %{"section_slug" => section.slug, "publication_id" => publication_id}
    |> Worker.new()
    |> Oban.insert!()

    updates_in_progress = Map.put(updates_in_progress, publication_id, true)

    {:noreply,
     socket
     |> assign(updates_in_progress: updates_in_progress)
     |> hide_modal()}
  end

  def handle_info({:update_progress, section_id, publication_id, :complete}, socket) do
    %{section: section} = socket.assigns

    if section_id == section.id do
      %{
        modal: modal,
        redirect_after_apply: redirect_after_apply,
        updates_in_progress: updates_in_progress
      } = socket.assigns

      case modal do
        %{assigns: %{publication_id: ^publication_id}} ->
          {:noreply,
           push_redirect(socket,
             to: redirect_after_apply
           )}

        _ ->
          {:noreply,
           assign(socket, updates_in_progress: Map.delete(updates_in_progress, publication_id))}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info({:update_progress, _section_id, _publication_id, _progress}, socket) do
    # ignore all other update progress events except for :complete handled above
    {:noreply, socket}
  end
end
