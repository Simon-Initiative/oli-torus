defmodule OliWeb.LiveSessionPlugs.InitPage do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]

  alias Oli.Delivery.{PreviousNextIndex, Settings}
  alias Oli.Delivery.Page.PageContext

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

    {:cont, socket}
  end

  # Display practice pages
  defp init_context_state(
         %PageContext{
           page: %{graded: false}
         } = page_context,
         socket
       ) do
    assign(socket, %{
      view: :practice_page,
      page_context: page_context
    })
  end

  # Display the prologue view for graded pages
  defp init_context_state(
         %PageContext{page: %{graded: true}} = page_context,
         socket
       ) do
    # Only consider graded attempts
    resource_attempts =
      Enum.filter(page_context.resource_attempts, fn a -> a.revision.graded end)

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
      view: :graded_page,
      page_context: %PageContext{page_context | historical_attempts: resource_attempts},
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

  defp plural(1), do: ""
  defp plural(_), do: "s"
end
