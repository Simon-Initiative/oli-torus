defmodule OliWeb.Delivery.ManageUpdates do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  import OliWeb.Delivery.Updates.Utils

  alias Oli.Delivery.Sections
  alias Oli.Publishing
  alias OliWeb.Delivery.Updates.ApplyUpdateModal

  alias OliWeb.Sections.Mount

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

      {_, _, %Oli.Delivery.Sections.Section{type: :blueprint} = section} ->
        init_state(
          socket,
          section,
          Routes.live_path(socket, OliWeb.Products.DetailsView, section.slug)
        )

      {_, _, section} ->
        init_state(socket, section, Map.get(session, "redirect_after_apply"))
    end
  end

  def init_state(socket, section, redirect_after_apply) do
    updates = Sections.check_for_available_publication_updates(section)

    {:ok,
     assign(socket,
       title: "Manage Updates",
       section: section,
       updates: updates,
       modal: nil,
       redirect_after_apply: redirect_after_apply
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
      redirect_after_apply: redirect_after_apply
    } = socket.assigns

    Sections.apply_publication_update(
      section,
      publication_id
    )

    {:noreply,
     push_redirect(socket,
       to: redirect_after_apply
     )}
  end
end
