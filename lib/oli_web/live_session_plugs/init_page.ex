defmodule OliWeb.LiveSessionPlugs.InitPage do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]

  alias Oli.Delivery.{PreviousNextIndex, Sections}
  alias Oli.Delivery.Page.PageContext
  alias OliWeb.Common.FormatDateTime

  def on_mount(
        :page_context,
        %{"revision_slug" => revision_slug},
        _session,
        %{assigns: assigns} = socket
      ) do
    numbered_revisions = Sections.get_revision_indexes(assigns.section.slug)

    socket =
      PageContext.create_for_visit(
        assigns.section,
        revision_slug,
        assigns.current_user,
        assigns.datashop_session_id
      )
      |> init_context_state(socket)
      |> assign(%{numbered_revisions: numbered_revisions})

    {:cont, socket}
  end

  def on_mount(
        :previous_next_index,
        _params,
        _session,
        %{assigns: assigns} = socket
      ) do
    {:ok, {previous, next, current}, _} =
      PreviousNextIndex.retrieve(assigns.section, assigns.page_context.page.resource_id)

    {:cont,
     assign(socket,
       previous_page: previous,
       next_page: next,
       current_page: current
     )}
  end

  # Display the prologue view
  defp init_context_state(
         %PageContext{
           progress_state: :not_started,
           page: page
         } = page_context,
         socket
       ) do
    section = socket.assigns.section

    section_resource = Sections.get_section_resource(section.id, page.resource_id)

    assign(socket, %{
      view: :prologue,
      page_number: section_resource.numbering_index,
      revision: page,
      resource_slug: page.slug,
      page_context: page_context
    })
  end

  # Handles the 2 cases of adaptive delivery
  #  1. A fullscreen chromeless version
  #  2. A version inside the torus navigation with an iframe pointing to #1
  defp init_context_state(
         %PageContext{
           page: %{
             content:
               %{
                 "advancedDelivery" => true
               } = content
           }
         } = page_context,
         socket
       ) do
    view =
      if Map.get(content, "displayApplicationChrome", false) do
        :page
      else
        :adaptive_chromeless
      end

    assign(socket, %{
      view: view,
      page_context: page_context
    })
  end

  defp init_context_state(
         %PageContext{progress_state: :error} = page_context,
         socket
       ) do
    assign(socket, %{
      view: :error,
      page_context: page_context
    })
  end

  defp init_context_state(page_context, socket) do
    section = socket.assigns.section

    section_resource = Sections.get_section_resource(section.id, page_context.page.resource_id)

    assign(socket, %{
      view: :page,
      page_number: section_resource.numbering_index,
      revision: page_context.page,
      resource_slug: page_context.page.slug,
      page_context: page_context
    })
  end
end
