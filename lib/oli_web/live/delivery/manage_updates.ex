defmodule OliWeb.Delivery.ManageUpdates do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  import OliWeb.Delivery.Updates.Utils

  alias Oli.Delivery.Sections
  alias Oli.Publishing
  alias Oli.Delivery.Updates.Worker
  alias OliWeb.Delivery.Updates.ApplyUpdateModal
  alias Oli.Delivery.Updates.Subscriber
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Sections.Mount

  def set_breadcrumbs(section, type) do
    type
    |> OliWeb.Sections.OverviewView.set_breadcrumbs(section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Manage Updates",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(
        params,
        session,
        socket
      ) do
    section_slug =
      case is_map(params) and Map.has_key?(params, "section_slug") do
        false -> Map.get(session, "section").slug
        true -> Map.get(params, "section_slug")
      end

    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {user_type, _, %Oli.Delivery.Sections.Section{type: :blueprint} = section} ->
        init_state(
          socket,
          section,
          Routes.live_path(socket, OliWeb.Products.DetailsView, section.slug),
          user_type
        )

      {user_type, _, section} ->
        init_state(socket, section, Map.get(session, "redirect_after_apply"), user_type)
    end
  end

  def init_state(socket, section, redirect_after_apply, user_type) do
    updates = Sections.check_for_available_publication_updates(section)
    updates_in_progress = Sections.check_for_updates_in_progress(section)

    Subscriber.subscribe_to_update_progress(section.id)

    {:ok,
     assign(socket,
       title: "Manage Updates",
       section: section,
       updates: updates,
       modal: nil,
       updates_in_progress: updates_in_progress,
       redirect_after_apply: redirect_after_apply,
       delivery_breadcrumb: true,
       breadcrumbs: set_breadcrumbs(section, user_type)
     )}
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
      modal: %{assigns: %{publication_id: publication_id}},
      updates_in_progress: updates_in_progress
    } = socket.assigns

    %{"section_slug" => section.slug, "publication_id" => publication_id}
    |> Worker.new()
    |> Oban.insert!()

    updates_in_progress = Map.put_new(updates_in_progress, publication_id, true)

    {:noreply,
     socket
     |> assign(updates_in_progress: updates_in_progress)
     |> hide_modal()}
  end

  @spec handle_info(
          {:update_progress, any, any, any},
          atom
          | %{
              :assigns => %{
                :section => atom | %{:id => any, optional(any) => any},
                optional(any) => any
              },
              optional(any) => any
            }
        ) :: {:noreply, any}
  def handle_info({:update_progress, section_id, publication_id, :complete}, socket) do
    %{section: section} = socket.assigns

    if section_id == section.id do
      %{
        updates: updates,
        updates_in_progress: updates_in_progress
      } = socket.assigns

      %{project_id: project_id} = Publishing.get_publication!(publication_id)

      {:noreply,
       assign(socket,
         updates: Map.delete(updates, project_id),
         updates_in_progress: Map.delete(updates_in_progress, publication_id)
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:update_progress, section_id, publication_id, _progress}, socket) do
    %{section: section} = socket.assigns

    if section_id == section.id do
      %{updates_in_progress: updates_in_progress} = socket.assigns

      updates_in_progress = Map.put_new(updates_in_progress, publication_id, true)

      {:noreply, assign(socket, updates_in_progress: updates_in_progress)}
    else
      {:noreply, socket}
    end
  end
end
