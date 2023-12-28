defmodule OliWeb.LiveSessionPlugs.InitPage do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]

  alias Oli.Activities
  alias Oli.Delivery.{PreviousNextIndex, Sections}
  alias Oli.Delivery.Page.PageContext
  alias Oli.Publishing.DeliveryResolver, as: Resolver
  alias Oli.Rendering.{Context, Page}
  alias Oli.Resources

  def on_mount(
        :page_context,
        %{"revision_slug" => revision_slug},
        _session,
        %{assigns: assigns} = socket
      ) do
    socket =
      PageContext.create_for_visit(
        assigns.section,
        revision_slug,
        assigns.current_user,
        assigns.datashop_session_id
      )
      |> init_context_state(socket)
      |> maybe_init_page_body()
      |> assign(numbered_revisions: Sections.get_revision_indexes(assigns.section.slug))

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

  defp maybe_init_page_body(%{assigns: %{view: :page}} = socket) do
    render_context = %Context{
      enrollment:
        Oli.Delivery.Sections.get_enrollment(
          socket.assigns.section.slug,
          socket.assigns.current_user.id
        ),
      user: socket.assigns.current_user,
      section_slug: socket.assigns.section.slug,
      # project_slug: base_project_slug,
      # resource_attempt: hd(context.resource_attempts),
      mode: :delivery,
      activity_map: socket.assigns.page_context.activities,
      resource_summary_fn: &Resources.resource_summary(&1, socket.assigns.section.slug, Resolver),
      alternatives_groups_fn: fn ->
        Resources.alternatives_groups(socket.assigns.section.slug, Resolver)
      end,
      alternatives_selector_fn: &Resources.Alternatives.select/2,
      extrinsic_read_section_fn: &Oli.Delivery.ExtrinsicState.read_section/3,
      bib_app_params: socket.assigns.page_context.bib_revisions,
      # submitted_surveys: submitted_surveys,
      historical_attempts: socket.assigns.page_context.historical_attempts,
      learning_language:
        Sections.get_section_attributes(socket.assigns.section).learning_language,
      effective_settings: socket.assigns.page_context.effective_settings
    }

    attempt_content = get_attempt_content(socket)

    # Cache the page as text to allow the AI agent LV to access it.
    cache_page_as_text(render_context, attempt_content, socket.assigns.page_context.page.id)

    assign(socket,
      html: Page.render(render_context, attempt_content, Page.Html),
      # TODO improvement: do not load all delivery scripts (~1.5mb each)
      # but just the one needed by the page
      scripts: Activities.get_activity_scripts(:delivery_script)
    )
  end

  defp maybe_init_page_body(socket), do: socket

  defp get_attempt_content(socket) do
    this_attempt = socket.assigns.page_context.resource_attempts |> hd

    if Enum.any?(this_attempt.errors, fn e ->
         e == "Selection failed to fulfill: no values provided for expression"
       end) and socket.assigns.page_context.is_student do
      %{"model" => []}
    else
      this_attempt.content
    end
  end

  defp cache_page_as_text(render_context, content, page_id) do
    Oli.Converstation.PageContentCache.put(
      page_id,
      Page.render(render_context, content, Page.Markdown) |> :erlang.iolist_to_binary()
    )
  end
end
