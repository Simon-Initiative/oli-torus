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

    IO.inspect(previous, label: "previous")
    IO.inspect(next, label: "next")
    IO.inspect(current, label: "current")

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

    # # Only consider graded attempts
    # resource_attempts = Enum.filter(resource_attempts, & &1.revision.graded)
    # attempts_taken = length(resource_attempts)

    preview_mode = Map.get(socket.assigns, :preview_mode, false)

    # # The Oli.Plugs.MaybeGatedResource plug sets the blocking_gates assign if there is a blocking
    # # gate that prevents this learning from starting another attempt of this resource
    # blocking_gates = Map.get(socket.assigns, :blocking_gates, [])

    # new_attempt_allowed =
    #   Settings.new_attempt_allowed(
    #     effective_settings,
    #     attempts_taken,
    #     blocking_gates
    #   )

    # allow_attempt? = new_attempt_allowed == {:allowed}

    # message =
    #   case new_attempt_allowed do
    #     {:blocking_gates} ->
    #       Oli.Delivery.Gating.details(blocking_gates,
    #         format_datetime: format_datetime_fn(socket.assigns.ctx)
    #       )

    #     {:no_attempts_remaining} ->
    #       "You have no attempts remaining out of #{effective_settings.max_attempts} total attempt#{plural(effective_settings.max_attempts)}."

    #     {:before_start_date} ->
    #       before_start_date_message(socket.assigns.ctx, effective_settings)

    #     {:end_date_passed} ->
    #       "The deadline for this assignment has passed."

    #     {:allowed} ->
    #       if effective_settings.max_attempts == 0 do
    #         "You can take this scored page an unlimited number of times"
    #       else
    #         attempts_remaining = effective_settings.max_attempts - attempts_taken

    #         "You have #{attempts_remaining} #{Gettext.ngettext(OliWeb.Gettext, "attempt", "attempts", attempts_remaining)} remaining out of #{effective_settings.max_attempts} #{Gettext.ngettext(OliWeb.Gettext, "attempt", "attempts", effective_settings.max_attempts)}."
    #       end
    #   end

    # resource_attempts =
    #   Enum.filter(resource_attempts, &(&1.date_submitted != nil))
    #   |> Enum.sort(&DateTime.before?(&1.date_submitted, &2.date_submitted))

    # {:ok, {previous, next, current}, _} = PreviousNextIndex.retrieve(section, page.resource_id)

    # resource_access = Core.get_resource_access(page.resource_id, section.slug, user.id)

    section_resource = Sections.get_section_resource(section.id, page.resource_id)

    # assign(socket, %{
    #   view: :prologue,
    #   resource_access: resource_access,
    #   section_slug: section_slug,
    #   scripts: Activities.get_activity_scripts(),
    #   preview_mode: preview_mode,
    #   resource_attempts: resource_attempts,
    #   previous_page: previous,
    #   next_page: next,
    #   numbered_revisions: numbered_revisions,
    #   current_page: current,
    # page_number: section_resource.numbering_index,
    #   title: context.page.title,
    #   allow_attempt?: allow_attempt?,
    #   message: message,
    #   resource_id: page.resource_id,
    #   slug: context.page.slug,
    #   max_attempts: effective_settings.max_attempts,
    #   effective_settings: effective_settings,
    #   requires_password?:
    #     effective_settings.password != nil and effective_settings.password != "",
    #   section: section,
    #   page_link_url: &Routes.page_delivery_path(conn, :page, section_slug, &1),
    #   container_link_url: &Routes.page_delivery_path(conn, :container, section_slug, &1),
    # revision: page_context.page,
    #   resource_slug: context.page.slug,
    #   bib_app_params: %{
    #     bibReferences: context.bib_revisions
    #   }
    # })
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

    preview_mode = Map.get(socket.assigns, :preview_mode, false)

    assign(socket, %{
      view: :page,
      page_number: section_resource.numbering_index,
      revision: page_context.page,
      resource_slug: page_context.page.slug,
      page_context: page_context
    })
  end

  defp before_start_date_message(session_context, effective_settings) do
    "This assessment is not yet available. It will be available on #{format_datetime_fn(session_context).(effective_settings.start_date)}."
  end

  defp format_datetime_fn(session_context) do
    fn datetime ->
      FormatDateTime.date(datetime, ctx: session_context, precision: :minutes)
    end
  end
end
