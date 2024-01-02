defmodule OliWeb.LiveSessionPlugs.InitPage do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]

  alias Oli.Delivery.{PreviousNextIndex, Sections, Settings}
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

    # Only consider graded attempts
    resource_attempts =
      Enum.filter(page_context.resource_attempts, fn a -> a.revision.graded == true end)

    attempts_taken = length(resource_attempts)

    # The Oli.Plugs.MaybeGatedResource plug sets the blocking_gates assign if there is a blocking
    # gate that prevents this learning from starting another attempt of this resource
    # TODO: get this blocking_gates from the conn and handle attempt_message for this case

    # blocking_gates = Map.get(conn.assigns, :blocking_gates, [])
    blocking_gates = []

    new_attempt_allowed =
      Settings.new_attempt_allowed(
        page_context.effective_settings,
        attempts_taken,
        blocking_gates
      )

    attempt_message =
      case {new_attempt_allowed, page_context.effective_settings.max_attempts} do
        # {{:blocking_gates}, _max_attempts} ->
        #  Oli.Delivery.Gating.details(blocking_gates, format_datetime: format_datetime_fn(conn))

        {{:no_attempts_remaining}, max_attempts} ->
          "You have no attempts remaining out of #{max_attempts} total attempt#{plural(max_attempts)}."

        {{:before_start_date}, _max_attempts} ->
          "This assessment is not yet available. It will be available on #{OliWeb.Common.FormatDateTime.date(page_context.effective_settings.start_date, precision: :minutes)}"

        {{:end_date_passed}, _max_attempts} ->
          "The deadline for this assignment has passed."

        {{:allowed}, 0} ->
          "You can take this scored page an unlimited number of times"

        {{:allowed}, max_attempts} ->
          attempts_remaining = max_attempts - attempts_taken

          "You have #{attempts_remaining} attempt#{plural(attempts_remaining)} remaining out of #{max_attempts} total attempt#{plural(max_attempts)}."
      end

    assign(socket, %{
      view: :prologue,
      page_number: section_resource.numbering_index,
      revision: page,
      resource_slug: page.slug,
      page_context: page_context,
      allow_attempt?: new_attempt_allowed == {:allowed},
      attempt_message: attempt_message
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

  defp maybe_init_page_body(%{assigns: %{view: :page} = assigns} = socket) do
    %{section: section, current_user: current_user, page_context: page_context} = assigns

    render_context = %Context{
      enrollment:
        Oli.Delivery.Sections.get_enrollment(
          section.slug,
          current_user.id
        ),
      user: current_user,
      section_slug: section.slug,
      mode: :delivery,
      activity_map: page_context.activities,
      resource_summary_fn: &Resources.resource_summary(&1, section.slug, Resolver),
      alternatives_groups_fn: fn ->
        Resources.alternatives_groups(section.slug, Resolver)
      end,
      alternatives_selector_fn: &Resources.Alternatives.select/2,
      extrinsic_read_section_fn: &Oli.Delivery.ExtrinsicState.read_section/3,
      bib_app_params: page_context.bib_revisions,
      historical_attempts: page_context.historical_attempts,
      learning_language: Sections.get_section_attributes(section).learning_language,
      effective_settings: page_context.effective_settings
      # when migrating from page_delivery_controller this key-values were found
      # to apparently not be used by the page template:
      #   project_slug: base_project_slug,
      #   submitted_surveys: submitted_surveys,
      #   resource_attempt: hd(context.resource_attempts)
    }

    attempt_content = get_attempt_content(page_context)

    # Cache the page as text to allow the AI agent LV to access it.
    cache_page_as_text(render_context, attempt_content, page_context.page.id)

    assign(socket,
      html: Page.render(render_context, attempt_content, Page.Html),
      scripts: get_required_activity_scripts(page_context.activities)
    )
  end

  defp maybe_init_page_body(socket), do: socket

  defp get_required_activity_scripts(activity_mapper) do
    # this is an optimization to exclude not needed activity scripts (~1.5mb each)
    Enum.map(activity_mapper, fn {_activity_id, activity} ->
      activity.script
    end)
    |> Enum.uniq()
  end

  defp get_attempt_content(page_context) do
    this_attempt = page_context.resource_attempts |> hd

    if Enum.any?(this_attempt.errors, fn e ->
         e == "Selection failed to fulfill: no values provided for expression"
       end) and page_context.is_student do
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

  defp plural(1), do: ""
  defp plural(_), do: "s"
end
