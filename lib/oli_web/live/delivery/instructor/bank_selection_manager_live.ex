defmodule OliWeb.Delivery.Instructor.BankSelectionManagerLive do
  use OliWeb, :live_view

  alias Phoenix.LiveView.JS
  alias Oli.Activities
  alias Oli.Delivery.InstructorCustomizations
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing.DeliveryResolver, as: Resolver
  alias Oli.Rendering.Content.ActivityBankSelectionCriteria
  alias Oli.Resources.Revision

  alias OliWeb.Components.Delivery.ActivityBankSelectionCriteria,
    as: ActivityBankSelectionCriteriaComponent

  alias OliWeb.Components.Modal
  alias OliWeb.Delivery.Instructor.PreviewPageContext
  alias OliWeb.Components.Delivery.Layouts
  alias OliWeb.Delivery.Instructor.{PreviewReturn, PreviewRoutes}
  alias OliWeb.Icons
  alias OliWeb.ManualGrading.RenderedActivity

  @candidate_row_limit 25
  @candidate_text_search_max_length 120
  @type selection_mode :: :none | :available | :removed | :mixed

  def mount(
        %{"revision_slug" => revision_slug, "selection_id" => selection_id} = params,
        _session,
        socket
      ) do
    section = socket.assigns.section
    navigation_params = navigation_params(params, section.slug)

    case InstructorCustomizations.resolve_bank_selection_preview_target(
           section,
           revision_slug,
           selection_id
         ) do
      {:error, {:not_found, :page}} ->
        {:ok, redirect(socket, to: PreviewRoutes.learn_path(section.slug, navigation_params))}

      {:error, {:invalid_page_type, :adaptive}} ->
        {:ok,
         redirect(
           socket,
           to:
             PreviewRoutes.adaptive_page_path(
               section.slug,
               revision_slug,
               adaptive_redirect_params(params)
             )
         )}

      {:error, {:not_found, :selection}} ->
        {:ok,
         socket
         |> put_flash(:error, "We couldn’t find that activity bank selection for this page.")
         |> redirect(
           to: PreviewRoutes.lesson_path(section.slug, revision_slug, navigation_params)
         )}

      {:ok, revision, selection} ->
        sidebar_expanded = preview_sidebar_state(params)
        candidate_preview_dependencies = candidate_preview_dependencies()

        criteria_presentation =
          ActivityBankSelectionCriteria.presentation(selection, section.slug)

        candidate_filters = default_candidate_filters()

        case load_candidates(section, revision, selection, filters: candidate_filters) do
          {:ok, candidate_page} ->
            candidate_filter_options =
              load_candidate_filter_options(
                section,
                revision,
                selection,
                candidate_page.total_count
              )

            preview_script_sources =
              candidate_surface_script_sources_for_selection(
                section,
                revision,
                selection,
                candidate_page.total_count,
                candidate_preview_dependencies.script_sources_by_activity_type_id
              )

            {:ok,
             socket
             |> assign(
               page_revision: revision,
               current_page_resource_id: revision.resource_id,
               selection: selection,
               selection_id: selection_id,
               selection_points_per_question: selection_points_per_question(selection),
               instructor_preview_return:
                 socket.assigns[:instructor_preview_return] ||
                   PreviewReturn.fallback_context(section.slug),
               selection_criteria_rows: criteria_presentation.rows,
               selection_criteria_helper_text: criteria_presentation.helper_text,
               navigation_params: navigation_params,
               sidebar_expanded: sidebar_expanded,
               request_path: local_back_path(section.slug, revision.slug, navigation_params),
               candidate_filters: candidate_filters,
               candidate_filter_options: candidate_filter_options,
               open_candidate_filter_id: nil,
               invalid_remove_warning: nil,
               candidate_preview_activity_types_map:
                 candidate_preview_dependencies.activity_types_map,
               candidate_preview_payloads_by_id: %{},
               candidate_preview_objective_titles_by_id: %{},
               candidate_revisions_by_id: %{},
               selected_candidate_preview_html: nil,
               preview_script_sources: preview_script_sources
             )
             |> assign_candidate_page(candidate_page)
             |> assign_selected_candidate_preview(), layout: false}

          {:error, _reason} ->
            {:ok,
             socket
             |> put_flash(:error, "Unable to load questions for this activity bank.")
             |> redirect(
               to: PreviewRoutes.lesson_path(section.slug, revision.slug, navigation_params)
             )}
        end

      {:error, _reason} ->
        {:ok,
         socket
         |> put_flash(:error, "Unable to open this activity bank manager.")
         |> redirect(
           to: PreviewRoutes.lesson_path(section.slug, revision_slug, navigation_params)
         )}
    end
  end

  def handle_event("select_candidate", %{"activity_resource_id" => activity_resource_id}, socket) do
    selected_candidate_id = parse_integer(activity_resource_id)

    cond do
      selected_candidate_id == socket.assigns.selected_candidate_id ->
        {:noreply, socket}

      Enum.any?(socket.assigns.candidates, &(&1.activity_resource_id == selected_candidate_id)) ->
        {:noreply,
         socket
         |> assign(:selected_candidate_id, selected_candidate_id)
         |> assign_selected_candidate_preview()}

      true ->
        {:noreply, socket}
    end
  end

  def handle_event(
        "toggle_candidate_checkbox",
        %{"activity_resource_id" => activity_resource_id},
        socket
      ) do
    candidate_id = parse_integer(activity_resource_id)

    if candidate = selected_candidate(socket.assigns.candidates, candidate_id) do
      # Checkbox state is scoped to the visible query result so list selection and
      # bulk actions stay aligned without persisting hidden rows across filters.
      {:noreply,
       socket
       |> update(
         :checked_candidate_ids,
         &toggle_checked_candidate_id(
           socket.assigns.candidates,
           &1,
           candidate.activity_resource_id
         )
       )
       |> push_selected_candidate_preview_bulk_state()}
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_all_candidate_checkboxes", _params, socket) do
    selectable_candidate_ids =
      master_selectable_candidate_ids(
        socket.assigns.candidates,
        socket.assigns.checked_candidate_ids
      )

    checked_candidate_ids =
      if all_selectable_candidates_checked?(
           socket.assigns.candidates,
           socket.assigns.checked_candidate_ids
         ) do
        MapSet.new()
      else
        MapSet.new(selectable_candidate_ids)
      end

    {:noreply,
     socket
     |> assign(:checked_candidate_ids, checked_candidate_ids)
     |> push_selected_candidate_preview_bulk_state()}
  end

  def handle_event("run_bulk_selection_action", _params, socket) do
    candidate_ids = checked_candidate_ids_in_visible_order(socket.assigns)

    case selection_mode(socket.assigns.candidates, socket.assigns.checked_candidate_ids)
         |> bulk_selection_action() do
      :remove ->
        run_bulk_candidate_action(socket, candidate_ids, false)

      :restore ->
        run_bulk_candidate_action(socket, candidate_ids, true)

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("filter_candidates", params, socket) do
    candidate_filters = candidate_filters_from_params(params, socket.assigns.candidate_filters)

    open_candidate_filter_id =
      Map.get(params, "_candidate_filter_id", socket.assigns.open_candidate_filter_id)

    filter_candidates(socket, candidate_filters, open_candidate_filter_id)
  end

  def handle_event("set_candidate_visibility", %{"visibility" => visibility}, socket) do
    candidate_filters =
      %{
        socket.assigns.candidate_filters
        | visibility: candidate_visibility_from_param(visibility)
      }

    filter_candidates(socket, candidate_filters)
  end

  def handle_event("clear_candidate_filters", _params, socket) do
    filter_candidates(socket, default_candidate_filters())
  end

  def handle_event("toggle_candidate_filter_dropdown", %{"filter_id" => filter_id}, socket) do
    open_candidate_filter_id =
      if socket.assigns.open_candidate_filter_id == filter_id, do: nil, else: filter_id

    {:noreply, assign(socket, :open_candidate_filter_id, open_candidate_filter_id)}
  end

  def handle_event("close_candidate_filter_dropdown", _params, socket) do
    {:noreply, assign(socket, :open_candidate_filter_id, nil)}
  end

  def handle_event("dismiss_invalid_remove_warning", _params, socket) do
    socket =
      case socket.assigns.invalid_remove_warning do
        %{target: target} ->
          # The React preview card sets a local "Updating..." state before the mutation round-trip.
          # Dismissing this modal is a failed/remove-aborted outcome, so we push a synthetic reply
          # back through the preview bridge to clear that client-only pending state.
          push_event(socket, "preview_customization_reply", %{ok: false, target: target})

        _ ->
          socket
      end

    {:noreply, assign(socket, :invalid_remove_warning, nil)}
  end

  def handle_event("confirm_remove_bank", _params, socket) do
    %{
      section: section,
      current_page_resource_id: page_resource_id,
      selection_id: selection_id,
      request_path: request_path,
      current_user: actor
    } = socket.assigns

    case InstructorCustomizations.exclude_bank_selection(
           section,
           page_resource_id,
           selection_id,
           actor: actor
         ) do
      {:ok, _view} ->
        {:noreply,
         socket
         |> assign(:invalid_remove_warning, nil)
         |> put_flash(:info, "Activity bank selection removed from this page.")
         |> redirect(to: request_path)}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:invalid_remove_warning, nil)
         |> put_flash(:error, "Unable to remove this activity bank selection.")}
    end
  end

  def handle_event(
        "load_more_candidates",
        _params,
        %{assigns: %{has_more_candidates?: false}} = socket
      ) do
    {:noreply, socket}
  end

  def handle_event("load_more_candidates", _params, socket) do
    %{
      section: section,
      page_revision: page_revision,
      selection: selection,
      candidate_filters: candidate_filters,
      candidate_offset: candidate_offset
    } = socket.assigns

    case load_candidates(
           section,
           page_revision,
           selection,
           offset: candidate_offset,
           filters: candidate_filters
         ) do
      {:ok, candidate_page} ->
        {:noreply, append_candidate_page(socket, candidate_page)}

      {:error, _reason} ->
        {:noreply,
         put_flash(socket, :error, "Unable to load more questions for this activity bank.")}
    end
  end

  def handle_event(
        "toggle_preview_activity_customization",
        %{
          "action" => action,
          "target" => %{
            "kind" => "bank_candidate",
            "pageResourceId" => page_resource_id,
            "selectionId" => selection_id,
            "activityResourceId" => activity_resource_id
          }
        },
        socket
      ) do
    target = %{
      kind: "bank_candidate",
      pageResourceId: page_resource_id,
      selectionId: selection_id,
      activityResourceId: activity_resource_id
    }

    result =
      with :ok <- validate_bank_candidate_target(socket, target),
           result <- run_bank_candidate_customization(socket, action, target) do
        result
      end

    handle_bank_candidate_customization_result(socket, target, action, result)
  end

  def handle_event(
        "toggle_preview_activity_customization",
        %{"action" => _action, "target" => %{"kind" => unsupported_kind}},
        socket
      ) do
    reply = %{ok: false, target: %{kind: unsupported_kind}}

    socket =
      put_flash(
        socket,
        :error,
        "Unsupported customization target #{unsupported_kind} for this activity bank manager."
      )

    {:reply, reply, socket}
  end

  defp filter_candidates(socket, candidate_filters, open_candidate_filter_id \\ nil) do
    %{
      section: section,
      page_revision: page_revision,
      selection: selection
    } = socket.assigns

    case load_candidates(section, page_revision, selection, filters: candidate_filters) do
      {:ok, candidate_page} ->
        {:noreply,
         socket
         |> assign(:candidate_filters, candidate_filters)
         |> assign(:open_candidate_filter_id, open_candidate_filter_id)
         |> replace_candidate_page(candidate_page)}

      {:error, _reason} ->
        {:noreply,
         put_flash(socket, :error, "Unable to filter questions for this activity bank.")}
    end
  end

  defp validate_bank_candidate_target(socket, target) do
    cond do
      target.pageResourceId != socket.assigns.current_page_resource_id ->
        {:error, :invalid_page_target}

      target.selectionId != socket.assigns.selection_id ->
        {:error, :invalid_selection_target}

      not candidate_visible?(socket.assigns.candidates, target.activityResourceId) ->
        {:error, :invalid_activity_target}

      true ->
        :ok
    end
  end

  defp run_bank_candidate_customization(socket, "remove", target) do
    InstructorCustomizations.exclude_bank_candidate(
      socket.assigns.section,
      target.pageResourceId,
      target.selectionId,
      target.activityResourceId,
      actor: socket.assigns.current_user
    )
  end

  defp run_bank_candidate_customization(socket, "restore", target) do
    InstructorCustomizations.restore_bank_candidate(
      socket.assigns.section,
      target.pageResourceId,
      target.selectionId,
      target.activityResourceId,
      actor: socket.assigns.current_user
    )
  end

  defp run_bank_candidate_customization(_socket, action, _target) do
    {:error, {:invalid_action, action}}
  end

  defp handle_bank_candidate_customization_result(socket, target, action, {:ok, _exclusion_view}) do
    reply = successful_bank_candidate_reply(target, action)

    with {:ok, refreshed_socket} <- refresh_candidate_page(socket) do
      {:reply, reply,
       refreshed_socket
       |> assign(:invalid_remove_warning, nil)
       |> put_flash(:info, bank_candidate_success_message(action))}
    else
      {:error, _reason} ->
        {:reply, %{ok: false, target: target},
         put_flash(socket, :error, "Unable to refresh this activity bank question.")}
    end
  end

  defp handle_bank_candidate_customization_result(
         socket,
         target,
         _action,
         {:error,
          {:insufficient_selection_candidates,
           %{count: count, active_candidates: active_candidates} = warning}}
       ) do
    reply = %{ok: false, target: target}
    warning = Map.put(warning, :target, target)

    {:reply, reply,
     assign(
       socket,
       :invalid_remove_warning,
       invalid_remove_warning_assigns(count, active_candidates, 1, warning)
     )}
  end

  defp handle_bank_candidate_customization_result(
         socket,
         target,
         _action,
         {:error, {:unauthorized, :customize_section}}
       ) do
    {:reply, %{ok: false, target: target},
     put_flash(socket, :error, "You are not allowed to customize this activity bank.")}
  end

  defp handle_bank_candidate_customization_result(
         socket,
         target,
         _action,
         {:error, :invalid_page_target}
       ) do
    {:reply, %{ok: false, target: target},
     put_flash(socket, :error, "Unable to update a question outside this activity bank manager.")}
  end

  defp handle_bank_candidate_customization_result(
         socket,
         target,
         _action,
         {:error, :invalid_selection_target}
       ) do
    {:reply, %{ok: false, target: target},
     put_flash(
       socket,
       :error,
       "Unable to update a question outside the current activity bank selection."
     )}
  end

  defp handle_bank_candidate_customization_result(
         socket,
         target,
         _action,
         {:error, :invalid_activity_target}
       ) do
    {:reply, %{ok: false, target: target},
     put_flash(socket, :error, "Unable to update a question that is not in this list.")}
  end

  defp handle_bank_candidate_customization_result(socket, target, _action, {:error, _reason}) do
    {:reply, %{ok: false, target: target},
     put_flash(socket, :error, "Unable to update this activity bank question.")}
  end

  defp successful_bank_candidate_reply(target, action) do
    %{
      ok: true,
      target: target,
      activityResourceId: target.activityResourceId,
      visualState: "default",
      statusPill: nil,
      actions:
        if(action == "remove",
          do: [%{kind: "restore", label: "Restore"}],
          else: [%{kind: "remove", label: "Remove"}]
        )
    }
  end

  defp bank_candidate_success_message("remove"),
    do: "Question removed from this activity bank selection."

  defp bank_candidate_success_message("restore"),
    do: "Question restored to this activity bank selection."

  defp bank_candidate_success_message(_action),
    do: "Activity bank question updated."

  defp run_bulk_candidate_action(socket, [], _enabled), do: {:noreply, socket}

  defp run_bulk_candidate_action(socket, candidate_ids, enabled) do
    action = if(enabled, do: :restore, else: :remove)

    case InstructorCustomizations.set_bank_candidates_enabled(
           socket.assigns.section,
           socket.assigns.current_page_resource_id,
           socket.assigns.selection_id,
           candidate_ids,
           enabled,
           actor: socket.assigns.current_user
         ) do
      {:ok, _view} ->
        with {:ok, refreshed_socket} <- refresh_candidate_page(socket) do
          {:noreply,
           refreshed_socket
           |> assign(:invalid_remove_warning, nil)
           |> put_flash(:info, bulk_candidate_success_message(action, length(candidate_ids)))}
        else
          {:error, _reason} ->
            {:noreply,
             put_flash(socket, :error, "Unable to refresh these activity bank questions.")}
        end

      {:error,
       {:insufficient_selection_candidates,
        %{count: count, active_candidates: active_candidates} = warning}} ->
        {:noreply,
         assign(
           socket,
           :invalid_remove_warning,
           invalid_remove_warning_assigns(
             count,
             active_candidates,
             length(candidate_ids),
             warning
           )
         )}

      {:error, {:unauthorized, :customize_section}} ->
        {:noreply,
         put_flash(socket, :error, "You are not allowed to customize this activity bank.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Unable to update these activity bank questions.")}
    end
  end

  defp bulk_candidate_success_message(:remove, 1),
    do: "1 question removed from this activity bank selection."

  defp bulk_candidate_success_message(:remove, count),
    do: "#{count} questions removed from this activity bank selection."

  defp bulk_candidate_success_message(:restore, 1),
    do: "1 question restored to this activity bank selection."

  defp bulk_candidate_success_message(:restore, count),
    do: "#{count} questions restored to this activity bank selection."

  defp candidate_visible?(candidates, activity_resource_id) do
    Enum.any?(candidates, &(&1.activity_resource_id == activity_resource_id))
  end

  def render(assigns) do
    ~H"""
    <div
      id="bank-selection-manager"
      data-preview-mode={@preview_mode}
      class="bg-Surface-surface-primary"
    >
      <script>
        window.userToken = "<%= @user_token %>";
      </script>

      <Layouts.instructor_preview_header return_context={@instructor_preview_return} />
      <Layouts.header
        ctx={@ctx}
        is_admin={@is_admin}
        section={@section}
        preview_mode={@preview_mode}
        sidebar_expanded={@sidebar_expanded}
        instructor_preview_return={@instructor_preview_return}
        include_logo
      />
      <div id="flash_container" class="container mx-auto sticky top-[8.5rem] z-[55] px-4">
        <.preview_flash_group flash={@flash} />
      </div>

      <div id="bank-selection-customization-bridge" phx-hook="InstructorPreviewCustomization"></div>
      <div
        id="bank-selection-preview-script-loader"
        phx-hook="LoadSurveyScripts"
        data-preview-activity-bridge="true"
        data-script-sources={Jason.encode!(@preview_script_sources || [])}
      >
      </div>
      <Modal.modal
        :if={@invalid_remove_warning}
        id="invalid-remove-bank-modal"
        show={true}
        on_cancel={JS.push("dismiss_invalid_remove_warning")}
        show_close={false}
        wrapper_class="flex w-full items-center justify-center p-4 sm:p-6"
        container_class="max-w-[673px] rounded-2xl border border-Border-border-default bg-Surface-surface-background shadow-[0px_2px_10px_0px_rgba(0,50,99,0.10)]"
        header_class="items-start justify-between px-8 pb-0 pt-8 sm:px-16 sm:pt-16"
        body_class="px-8 pb-8 pt-6 sm:px-16 sm:pb-16"
        title_class="font-open-sans text-[18px] font-semibold leading-6 text-Text-text-high"
      >
        <:title>
          {@invalid_remove_warning.title}
        </:title>
        <:header_actions>
          <button
            type="button"
            class="absolute right-6 top-6 inline-flex h-5 w-5 items-center justify-center text-Icon-icon-default transition hover:text-Icon-icon-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary sm:right-6 sm:top-6"
            phx-click={
              Modal.hide_modal(JS.push("dismiss_invalid_remove_warning"), "invalid-remove-bank-modal")
            }
            aria-label="Close modal"
          >
            <Icons.close_sm class="h-4 w-4 stroke-current" />
          </button>
        </:header_actions>
        <p class="font-open-sans text-base font-normal leading-6 text-Text-text-high">
          This activity bank selection <strong class="font-open-sans font-bold text-Text-text-high">
            requires {@invalid_remove_warning.count} {question_word(@invalid_remove_warning.count)}
          </strong>, and removing
          <strong class="font-open-sans font-bold text-Text-text-high">
            {@invalid_remove_warning.removal_subject}
          </strong>
          <strong class="font-open-sans font-bold text-Text-text-high">
            would leave only {@invalid_remove_warning.active_candidates}
          </strong>. To make changes, you can remove the entire activity bank selection.
        </p>
        <:custom_footer>
          <div class="flex flex-wrap justify-end gap-4 px-8 pb-8 sm:gap-6 sm:px-16 sm:pb-16">
            <button
              id="invalid-remove-bank-modal-remove-bank"
              type="button"
              phx-click="confirm_remove_bank"
              phx-disable-with="Removing bank..."
              class="inline-flex items-center justify-center rounded-md border border-Border-border-bold bg-Surface-surface-background px-6 py-2 font-open-sans text-sm font-semibold leading-4 text-Specially-Tokens-Text-text-button-secondary shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] transition hover:border-Border-border-bold-hover hover:bg-Surface-surface-secondary-hover hover:text-Specially-Tokens-Text-text-button-secondary-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
            >
              Remove bank
            </button>
            <button
              id="invalid-remove-bank-modal-keep-question"
              type="button"
              phx-click={
                Modal.hide_modal(
                  JS.push("dismiss_invalid_remove_warning"),
                  "invalid-remove-bank-modal"
                )
              }
              class="inline-flex items-center justify-center rounded-md bg-Fill-Buttons-fill-primary px-6 py-2 font-open-sans text-sm font-semibold leading-4 text-Text-text-white shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] transition hover:bg-Fill-Buttons-fill-primary-hover hover:text-Specially-Tokens-Text-text-button-primary-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
            >
              {@invalid_remove_warning.keep_label}
            </button>
          </div>
        </:custom_footer>
      </Modal.modal>
      <div class="flex-1 flex flex-col w-full">
        <div class="flex-1 mt-4 sm:mt-20 px-4 sm:px-[80px] relative">
          <div class="container mx-auto max-w-[1240px] pb-20 pt-6">
            <.local_back_nav request_path={@request_path} />

            <div class="mt-8">
              <header>
                <h1 class="text-2xl font-bold leading-8 text-Text-text-high">
                  Activity Bank Selection
                </h1>
                <p class="mt-4 text-base font-bold leading-4 text-Text-text-high">
                  <span id="active-available-count">{@active_available_count}</span>
                  questions available
                </p>

                <div class="mt-6 flex flex-wrap items-center gap-x-8 gap-y-2 text-sm leading-4 text-Text-text-high">
                  <div class="flex items-center gap-1">
                    <span class="font-bold text-Text-text-high">Selects:</span>
                    <span id="questions-required-count">
                      {@selection_count} {if @selection_count == 1,
                        do: "question",
                        else: "questions"}
                    </span>
                  </div>
                  <div class="flex items-center gap-1">
                    <span class="font-bold text-Text-text-high">Points per question:</span>
                    <span>{@selection_points_per_question}</span>
                  </div>
                </div>

                <div class="mt-5">
                  <ActivityBankSelectionCriteriaComponent.selection_criteria
                    rows={@selection_criteria_rows}
                    helper_text={@selection_criteria_helper_text}
                  />
                </div>
              </header>

              <div class="mt-10">
                <% bulk_selection_state =
                  bulk_selection_view_state(@candidates, @checked_candidate_ids) %>

                <div
                  id="candidate-visibility-filters"
                  class="mb-3 flex flex-wrap items-center gap-2"
                  role="group"
                  aria-label="Question visibility filter"
                >
                  <.candidate_visibility_button
                    id="candidate-visibility-all"
                    visibility="all"
                    current_visibility={@candidate_filters.visibility}
                  >
                    Show All
                  </.candidate_visibility_button>
                  <.candidate_visibility_button
                    id="candidate-visibility-available"
                    visibility="available"
                    current_visibility={@candidate_filters.visibility}
                  >
                    Available
                  </.candidate_visibility_button>
                  <.candidate_visibility_button
                    id="candidate-visibility-removed"
                    visibility="removed"
                    current_visibility={@candidate_filters.visibility}
                  >
                    Removed
                  </.candidate_visibility_button>
                </div>

                <div
                  id="candidate-advanced-filters"
                  class="mb-4 inline-flex max-w-full flex-wrap items-center gap-2 bg-Surface-surface-primary p-2.5 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.10)]"
                  role="group"
                  aria-label="Advanced question filters"
                >
                  <form
                    id="candidate-search-form"
                    phx-change="filter_candidates"
                    phx-submit="filter_candidates"
                    class="flex h-[35px] w-full max-w-[224px] items-center gap-3 rounded-md border border-Specially-Tokens-Border-border-input bg-Specially-Tokens-Fill-fill-input px-2 py-1 shadow-[0px_2px_5px_0px_rgba(0,50,99,0.10)]"
                  >
                    <Icons.search class="h-5 w-5 shrink-0 text-Icon-icon-default" />
                    <label for="candidate-search-input" class="sr-only">Search questions</label>
                    <input
                      id="candidate-search-input"
                      type="search"
                      name="text_search"
                      value={@candidate_filters.text_search}
                      phx-debounce="300"
                      autocomplete="off"
                      class="min-w-0 flex-1 border-none bg-transparent p-0 font-open-sans text-base font-normal leading-6 text-Text-text-high placeholder:text-Text-text-low focus:outline-none focus:ring-0"
                    />
                  </form>

                  <.candidate_multi_select_filter
                    id="candidate-objective-filter"
                    label="Learning Objectives"
                    param_name="objective_ids"
                    options={@candidate_filter_options.learning_objectives}
                    selected_ids={@candidate_filters.objective_ids}
                    open={@open_candidate_filter_id == "candidate-objective-filter"}
                  />

                  <.candidate_multi_select_filter
                    id="candidate-activity-type-filter"
                    label="Question Type"
                    param_name="activity_type_ids"
                    options={@candidate_filter_options.activity_types}
                    selected_ids={@candidate_filters.activity_type_ids}
                    open={@open_candidate_filter_id == "candidate-activity-type-filter"}
                  />

                  <button
                    id="candidate-clear-filters"
                    type="button"
                    phx-click="clear_candidate_filters"
                    class="inline-flex h-[35px] items-center gap-1.5 px-2 font-open-sans text-sm font-normal leading-none text-Text-text-high transition hover:text-Text-text-button focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
                  >
                    <Icons.trash class="h-4 w-4" /> Clear All Filters
                  </button>
                </div>

                <div :if={bulk_selection_state.action} class="mb-4">
                  <button
                    id="bulk-selection-action-button"
                    type="button"
                    phx-click="run_bulk_selection_action"
                    class={bulk_selection_state.button_classes}
                  >
                    <span
                      :if={bulk_selection_state.action == :remove}
                      aria-hidden="true"
                    >
                      <Icons.trash class="h-4 w-4 stroke-current" />
                    </span>
                    <span
                      :if={bulk_selection_state.action == :restore}
                      aria-hidden="true"
                    >
                      <Icons.restore class="h-4 w-4 stroke-current" />
                    </span>
                    {bulk_selection_state.action_label}
                  </button>
                </div>

                <div class="mt-4 text-sm font-normal text-gray-500 leading-5">
                  Showing {length(@candidates)} of {@total_candidate_count} questions
                </div>

                <div class="mt-2 grid xl:grid-cols-[420px_minmax(0,1fr)]">
                  <div
                    id="candidate-list"
                    role="listbox"
                    aria-label="Candidate questions"
                    class="min-w-0 border-t border-Border-border-default"
                  >
                    <div class="grid grid-cols-[28px_minmax(0,1fr)] shrink-0 items-center gap-2 border-b border-Table-table-border bg-Table-table-top-row p-2.5 h-12 text-Text-text-high text-base font-semibold">
                      <input
                        id="candidate-list-header-checkbox"
                        type="checkbox"
                        aria-label="Select all visible questions"
                        checked={bulk_selection_state.all_selectable_checked?}
                        phx-click="toggle_all_candidate_checkboxes"
                        class="h-4 w-4 rounded-[2px] border-Border-border-default text-Fill-Buttons-fill-primary focus:ring-Fill-Buttons-fill-primary"
                      />
                      <span>Question</span>
                    </div>

                    <div class="flex flex-col h-[calc(100vh-300px)] overflow-scroll">
                      <div
                        :if={@candidates == []}
                        id="candidate-list-empty-state"
                        class="flex min-h-32 items-center justify-center border-b border-Table-table-border px-6 py-8 text-center text-sm text-Text-text-low"
                      >
                        {candidate_empty_state_message(@candidate_filters)}
                      </div>

                      <div
                        :for={candidate <- @candidates}
                        id={"candidate-row-#{candidate.activity_resource_id}"}
                        role="option"
                        aria-selected={candidate_selected?(candidate, @selected_candidate_id)}
                        data-candidate-enabled={to_string(candidate.enabled?)}
                        data-candidate-selectable={
                          to_string(
                            Map.get(
                              bulk_selection_state.selectable_candidate_lookup,
                              candidate.activity_resource_id,
                              false
                            )
                          )
                        }
                        class={
                          candidate_row_classes(
                            candidate,
                            @selected_candidate_id,
                            Map.get(
                              bulk_selection_state.selectable_candidate_lookup,
                              candidate.activity_resource_id,
                              false
                            ),
                            bulk_selection_state.active?
                          )
                        }
                      >
                        <input
                          id={"candidate-checkbox-#{candidate.activity_resource_id}"}
                          type="checkbox"
                          aria-label={"Select #{candidate.title}"}
                          checked={candidate_checked?(candidate, @checked_candidate_ids)}
                          data-selection-mode={
                            bulk_selection_state.selection_mode |> Atom.to_string()
                          }
                          disabled={
                            !Map.get(
                              bulk_selection_state.selectable_candidate_lookup,
                              candidate.activity_resource_id,
                              false
                            )
                          }
                          phx-click="toggle_candidate_checkbox"
                          phx-value-activity_resource_id={candidate.activity_resource_id}
                          class="h-4 w-4 rounded-[2px] border-Border-border-default text-Fill-Buttons-fill-primary focus:ring-Fill-Buttons-fill-primary"
                        />
                        <button
                          id={"candidate-select-#{candidate.activity_resource_id}"}
                          type="button"
                          phx-click="select_candidate"
                          phx-value-activity_resource_id={candidate.activity_resource_id}
                          class="min-w-0 text-left"
                        >
                          <div class="truncate text-base font-medium text-Text-text-high">
                            {candidate.title}
                          </div>
                          <div
                            :if={!candidate.enabled?}
                            class="mt-2.5 inline-flex items-center rounded-full border border-Border-border-danger bg-Fill-fill-danger px-3 text-sm font-normal text-Text-text-danger"
                          >
                            Removed
                          </div>
                        </button>
                      </div>
                    </div>

                    <div
                      :if={remaining_candidate_count(@total_candidate_count, @candidates) > 0}
                      class="px-4 py-3"
                    >
                      <button
                        id="load-more-candidates"
                        type="button"
                        phx-click="load_more_candidates"
                        class="inline-flex cursor-pointer rounded-md px-6 py-2 text-sm font-semibold text-Text-text-button transition hover:text-Text-text-button-hover"
                      >
                        Load {min(
                          remaining_candidate_count(@total_candidate_count, @candidates),
                          @candidate_limit
                        )} more ({remaining_candidate_count(@total_candidate_count, @candidates)} remaining)
                      </button>
                    </div>
                  </div>

                  <%= if candidate = selected_candidate(@candidates, @selected_candidate_id) do %>
                    <%= if @selected_candidate_preview_html do %>
                      <div
                        id={
                          "selected-candidate-preview-shell-#{candidate.activity_resource_id}-#{preview_shell_state_key(@candidates, @checked_candidate_ids)}"
                        }
                        data-bulk-selection-active={
                          to_string(bulk_selection_active?(@checked_candidate_ids))
                        }
                        phx-update="ignore"
                        class="-mt-5 ml-1"
                      >
                        <RenderedActivity.render
                          id={"selected-candidate-preview-#{candidate.activity_resource_id}"}
                          rendered_activity={@selected_candidate_preview_html}
                        />
                      </div>
                    <% else %>
                      <div class="rounded-lg border border-dashed border-Border-border-default bg-Surface-surface-secondary-hover px-6 py-12 text-center text-sm text-Text-text-low">
                        We couldn’t render a preview for this question right now.
                      </div>
                    <% end %>
                  <% else %>
                    <div class="rounded-lg border border-dashed border-Border-border-default bg-Surface-surface-secondary-hover px-6 py-12 text-center text-sm text-Text-text-low">
                      {candidate_empty_state_message(@candidate_filters)}
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :visibility, :string, required: true
  attr :current_visibility, :atom, required: true
  slot :inner_block, required: true

  defp candidate_visibility_button(assigns) do
    assigns =
      assign(
        assigns,
        :selected?,
        assigns.current_visibility == candidate_visibility_from_param(assigns.visibility)
      )

    ~H"""
    <button
      id={@id}
      type="button"
      phx-click="set_candidate_visibility"
      phx-value-visibility={@visibility}
      aria-pressed={to_string(@selected?)}
      class={[
        "inline-flex min-h-10 items-center justify-center rounded-md border px-4 py-2 font-open-sans text-base font-semibold leading-6 transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary",
        if(@selected?,
          do: "border-Text-text-button bg-Background-bg-primary text-Text-text-button",
          else:
            "border-Border-border-default bg-Background-bg-primary text-Text-text-high hover:bg-Surface-surface-secondary-hover"
        )
      ]}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :param_name, :string, required: true
  attr :options, :list, required: true
  attr :selected_ids, :list, required: true
  attr :open, :boolean, required: true

  defp candidate_multi_select_filter(assigns) do
    assigns =
      assign(assigns,
        label_text: candidate_filter_label(assigns.label, assigns.selected_ids)
      )

    ~H"""
    <details
      id={@id}
      class="group relative"
      open={@open}
      phx-click-away="close_candidate_filter_dropdown"
    >
      <summary
        id={"#{@id}-toggle"}
        phx-click="toggle_candidate_filter_dropdown"
        phx-value-filter_id={@id}
        class="flex h-[35px] cursor-pointer list-none items-center justify-center gap-2.5 rounded-[3px] border border-Border-border-default bg-Surface-surface-primary px-2.5 font-open-sans text-base font-semibold leading-6 text-Text-text-high marker:hidden focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary [&::-webkit-details-marker]:hidden"
      >
        <span class="max-w-[180px] truncate">{@label_text}</span>
        <Icons.chevron_down
          width="16"
          height="16"
          class="h-4 w-4 fill-Icon-icon-default transition-transform group-open:rotate-180"
        />
      </summary>
      <form
        id={"#{@id}-form"}
        phx-change="filter_candidates"
        class="absolute left-0 top-[38px] z-[60] w-[220px] rounded-md border border-Specially-Tokens-Border-border-input bg-Specially-Tokens-Fill-fill-input px-3 py-2 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.10)]"
      >
        <input type="hidden" name="_candidate_filter_id" value={@id} />
        <input type="hidden" name={"#{@param_name}[]"} value="" />
        <div
          :if={@options == []}
          id={"#{@id}-empty"}
          class="py-1 font-open-sans text-sm font-normal leading-6 text-Text-text-low"
        >
          No options
        </div>
        <label
          :for={option <- @options}
          id={"#{@id}-option-#{option.id}"}
          class="flex cursor-pointer items-center gap-1.5 py-1 font-open-sans text-sm font-normal leading-6 text-Text-text-high"
        >
          <input
            id={"#{@id}-checkbox-#{option.id}"}
            type="checkbox"
            name={"#{@param_name}[]"}
            value={option.id}
            checked={option.id in @selected_ids}
            class="h-4 w-4 rounded-none border-Border-border-bold text-Fill-Buttons-fill-primary focus:ring-Fill-Buttons-fill-primary"
          />
          <span class="min-w-0 truncate">{option.title}</span>
        </label>
      </form>
    </details>
    """
  end

  attr :request_path, :string, required: true

  defp local_back_nav(assigns) do
    ~H"""
    <div class="inline-flex">
      <.link
        href={@request_path}
        class="inline-flex items-center gap-1.5 text-xs font-semibold text-Text-text-low transition hover:text-Text-text-high"
      >
        <Icons.back_arrow class="h-3.5 w-3.5 [&>path]:stroke-current" />
        <span>Back</span>
      </.link>
    </div>
    """
  end

  defp assign_candidate_page(socket, candidate_page) do
    candidates = candidate_page.candidates

    candidate_revisions_by_id =
      resolve_candidate_revisions(socket.assigns.section.slug, candidates)

    candidate_preview_payloads_by_id =
      resolve_candidate_preview_payloads(Map.values(candidate_revisions_by_id))

    candidate_preview_objective_titles_by_id =
      resolve_candidate_objective_titles(
        socket.assigns.section.id,
        Map.values(candidate_revisions_by_id)
      )

    # State model note:
    # - `candidates` is the currently shown result set for the active query
    # - `checked_candidate_ids` is ephemeral bulk-selection state for those shown rows
    # - future filter/search URL params should redefine the active query, not persist checked ids
    socket
    |> assign(
      candidates: candidates,
      candidate_preview_payloads_by_id: candidate_preview_payloads_by_id,
      candidate_preview_objective_titles_by_id: candidate_preview_objective_titles_by_id,
      candidate_revisions_by_id: candidate_revisions_by_id,
      checked_candidate_ids: MapSet.new(),
      selection_count: candidate_page.count,
      active_available_count: candidate_page.active_count,
      total_candidate_count: candidate_page.total_count,
      candidate_offset: length(candidates),
      candidate_limit: candidate_page.limit,
      has_more_candidates?: candidate_page.has_more?,
      selected_candidate_id: default_selected_candidate_id(candidates)
    )
  end

  defp append_candidate_page(socket, candidate_page) do
    # Paging can append many rows over time, so dedupe with a set instead of
    # rescanning the existing list for every incoming candidate.
    existing_ids = MapSet.new(Enum.map(socket.assigns.candidates, & &1.activity_resource_id))

    new_candidates =
      Enum.reject(candidate_page.candidates, fn appended ->
        MapSet.member?(existing_ids, appended.activity_resource_id)
      end)

    candidates = socket.assigns.candidates ++ new_candidates

    # Candidate preview selection can hop across the visible list, so resolve
    # newly appended revisions in one batch instead of one query per click later.
    appended_revisions_by_id =
      resolve_candidate_revisions(socket.assigns.section.slug, new_candidates)

    appended_preview_payloads_by_id =
      resolve_candidate_preview_payloads(Map.values(appended_revisions_by_id))

    appended_objective_titles_by_id =
      resolve_candidate_objective_titles(
        socket.assigns.section.id,
        Map.values(appended_revisions_by_id)
      )

    socket
    |> assign(
      candidates: candidates,
      candidate_preview_payloads_by_id:
        Map.merge(
          socket.assigns.candidate_preview_payloads_by_id,
          appended_preview_payloads_by_id
        ),
      candidate_preview_objective_titles_by_id:
        Map.merge(
          socket.assigns.candidate_preview_objective_titles_by_id,
          appended_objective_titles_by_id
        ),
      candidate_revisions_by_id:
        Map.merge(socket.assigns.candidate_revisions_by_id, appended_revisions_by_id),
      checked_candidate_ids:
        normalize_checked_candidate_ids(candidates, socket.assigns.checked_candidate_ids),
      selection_count: candidate_page.count,
      active_available_count: candidate_page.active_count,
      total_candidate_count: candidate_page.total_count,
      candidate_offset: length(candidates),
      candidate_limit: candidate_page.limit,
      has_more_candidates?: candidate_page.has_more?,
      selected_candidate_id:
        socket.assigns.selected_candidate_id || default_selected_candidate_id(candidates)
    )
  end

  defp load_candidates(%Section{} = section, %Revision{} = page_revision, selection, opts) do
    InstructorCustomizations.list_bank_selection_candidates(
      section,
      page_revision,
      selection,
      Keyword.put_new(opts, :limit, @candidate_row_limit)
    )
  end

  defp load_candidate_filter_options(
         %Section{} = section,
         %Revision{} = page_revision,
         selection,
         total_count
       ) do
    case InstructorCustomizations.list_bank_selection_candidate_filter_options(
           section,
           page_revision,
           selection,
           total_count
         ) do
      {:ok, options} -> options
      {:error, _reason} -> %{learning_objectives: [], activity_types: []}
    end
  end

  defp refresh_candidate_page(socket) do
    visible_candidate_count =
      max(length(socket.assigns.candidates), socket.assigns.candidate_limit)

    with {:ok, candidate_page} <-
           load_candidates(
             socket.assigns.section,
             socket.assigns.page_revision,
             socket.assigns.selection,
             limit: visible_candidate_count,
             filters: socket.assigns.candidate_filters
           ) do
      {:ok, replace_candidate_page(socket, candidate_page)}
    end
  end

  defp default_selected_candidate_id([candidate | _]), do: candidate.activity_resource_id
  defp default_selected_candidate_id([]), do: nil

  defp assign_selected_candidate_preview(socket) do
    case selected_candidate(socket.assigns.candidates, socket.assigns.selected_candidate_id) do
      nil ->
        assign(socket, :selected_candidate_preview_html, nil)

      candidate ->
        with %Revision{} = activity_revision <-
               Map.get(socket.assigns.candidate_revisions_by_id, candidate.activity_resource_id),
             {:ok, %{html: html}} <-
               PreviewPageContext.build_bank_candidate_preview(
                 socket.assigns.section,
                 socket.assigns.page_revision,
                 activity_revision,
                 encoded_model:
                   socket.assigns.candidate_preview_payloads_by_id
                   |> Map.get(candidate.activity_resource_id, %{})
                   |> Map.get(:encoded_model),
                 points:
                   socket.assigns.candidate_preview_payloads_by_id
                   |> Map.get(candidate.activity_resource_id, %{})
                   |> Map.get(:points),
                 activity_types_map: socket.assigns.candidate_preview_activity_types_map,
                 learning_objectives:
                   Map.get(
                     socket.assigns.candidate_preview_objective_titles_by_id,
                     candidate.activity_resource_id,
                     []
                   ),
                 selection_id: socket.assigns.selection_id,
                 can_customize?: true,
                 actions:
                   candidate_preview_actions(
                     candidate,
                     bulk_selection_active?(socket.assigns.checked_candidate_ids)
                   )
               ) do
          assign(socket, :selected_candidate_preview_html, html)
        else
          _ ->
            assign(socket, :selected_candidate_preview_html, nil)
        end
    end
  end

  defp push_selected_candidate_preview_bulk_state(socket) do
    case selected_candidate(socket.assigns.candidates, socket.assigns.selected_candidate_id) do
      nil ->
        socket

      candidate ->
        push_event(socket, "preview_customization_reply", %{
          ok: true,
          target: %{
            kind: "bank_candidate",
            pageResourceId: socket.assigns.current_page_resource_id,
            selectionId: socket.assigns.selection_id,
            activityResourceId: candidate.activity_resource_id
          },
          actions:
            candidate_preview_actions(
              candidate,
              bulk_selection_active?(socket.assigns.checked_candidate_ids)
            )
        })
    end
  end

  defp candidate_preview_actions(candidate, bulk_selection_active?) do
    if candidate.enabled? do
      [%{kind: "remove", label: "Remove", disabled: bulk_selection_active?}]
    else
      [%{kind: "restore", label: "Restore", disabled: bulk_selection_active?}]
    end
  end

  # Each activity type contributes whichever script the instructor-preview surface actually
  # needs: preview JS for types with dedicated preview support, or authoring JS for the
  # fallback path used by activity types that are not yet preview-capable (see Oli.Activities.preview_supported_activity_slug?).
  defp candidate_preview_dependencies do
    activity_types = Activities.list_activity_registrations()

    %{
      activity_types_map:
        Map.new(activity_types, fn activity_type -> {activity_type.id, activity_type} end),
      script_sources_by_activity_type_id:
        Enum.reduce(activity_types, %{}, fn activity_type, acc ->
          case PreviewPageContext.preview_script_for_registration(activity_type) do
            nil -> acc
            script -> Map.put(acc, activity_type.id, "/js/#{script}")
          end
        end)
    }
  end

  defp candidate_surface_script_sources_for_selection(
         section,
         page_revision,
         selection,
         total_count,
         script_sources_by_activity_type_id
       ) do
    case InstructorCustomizations.list_bank_selection_candidate_activity_type_ids(
           section,
           page_revision,
           selection,
           total_count
         ) do
      {:ok, activity_type_ids} ->
        activity_type_ids
        |> Enum.map(&Map.get(script_sources_by_activity_type_id, &1))
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      {:error, _reason} ->
        []
    end
  end

  defp selected_candidate(candidates, selected_candidate_id) do
    Enum.find(candidates, &(&1.activity_resource_id == selected_candidate_id))
  end

  defp resolve_candidate_revisions(_section_slug, []), do: %{}

  defp resolve_candidate_revisions(section_slug, candidates) do
    # The visible candidate list already has all resource ids we need, so batch
    # resolution here avoids a resolver query every time the right-side preview changes.
    candidate_ids = Enum.map(candidates, & &1.activity_resource_id)

    section_slug
    |> Resolver.from_resource_id(candidate_ids)
    |> Enum.reject(&is_nil/1)
    |> Map.new(fn revision -> {revision.resource_id, revision} end)
  end

  defp resolve_candidate_objective_titles(_section_id, []), do: %{}

  defp resolve_candidate_objective_titles(section_id, candidate_revisions) do
    # The preview only needs objective titles, so reuse the depot cache once
    # per visible batch instead of recomputing them for every selection change.
    PreviewPageContext.objective_titles_by_activity_id(section_id, candidate_revisions)
  end

  defp resolve_candidate_preview_payloads(candidate_revisions) do
    # Encoding the activity model is one of the few remaining CPU costs per
    # selection change, so precompute it once for the visible batch.
    Map.new(candidate_revisions, fn revision ->
      {revision.resource_id,
       %{
         encoded_model:
           revision.content
           |> Jason.encode!()
           |> Oli.Delivery.Page.ActivityContext.encode(),
         points: Oli.Grading.determine_activity_out_of(revision)
       }}
    end)
  end

  defp replace_candidate_page(socket, candidate_page) do
    candidates = candidate_page.candidates

    candidate_revisions_by_id =
      resolve_candidate_revisions(socket.assigns.section.slug, candidates)

    candidate_preview_payloads_by_id =
      resolve_candidate_preview_payloads(Map.values(candidate_revisions_by_id))

    candidate_preview_objective_titles_by_id =
      resolve_candidate_objective_titles(
        socket.assigns.section.id,
        Map.values(candidate_revisions_by_id)
      )

    selected_candidate_id =
      if Enum.any?(candidates, &(&1.activity_resource_id == socket.assigns.selected_candidate_id)) do
        socket.assigns.selected_candidate_id
      else
        default_selected_candidate_id(candidates)
      end

    socket
    |> assign(
      candidates: candidates,
      candidate_preview_payloads_by_id: candidate_preview_payloads_by_id,
      candidate_preview_objective_titles_by_id: candidate_preview_objective_titles_by_id,
      candidate_revisions_by_id: candidate_revisions_by_id,
      checked_candidate_ids:
        normalize_checked_candidate_ids(candidates, socket.assigns.checked_candidate_ids),
      selection_count: candidate_page.count,
      active_available_count: candidate_page.active_count,
      total_candidate_count: candidate_page.total_count,
      candidate_offset: length(candidates),
      candidate_limit: candidate_page.limit,
      has_more_candidates?: candidate_page.has_more?,
      selected_candidate_id: selected_candidate_id
    )
    |> assign_selected_candidate_preview()
  end

  defp checked_candidate_ids_in_visible_order(assigns) do
    assigns.candidates
    |> Enum.filter(&candidate_checked?(&1, assigns.checked_candidate_ids))
    |> Enum.map(& &1.activity_resource_id)
  end

  defp toggle_checked_candidate_id(candidates, checked_candidate_ids, candidate_id) do
    if MapSet.member?(checked_candidate_ids, candidate_id) do
      MapSet.delete(checked_candidate_ids, candidate_id)
    else
      case selected_candidate(candidates, candidate_id) do
        nil ->
          checked_candidate_ids

        candidate ->
          # The first checked row establishes the active selection mode for the
          # currently shown query result: available or removed.
          case selection_mode(candidates, checked_candidate_ids) do
            :none ->
              MapSet.put(checked_candidate_ids, candidate_id)

            selection_mode ->
              # Once a mode is active, opposite-state rows stay unchecked so
              # bulk selection can never mix available and removed ids.
              if candidate_state(candidate) == selection_mode do
                MapSet.put(checked_candidate_ids, candidate_id)
              else
                checked_candidate_ids
              end
          end
      end
    end
  end

  defp normalize_checked_candidate_ids(candidates, checked_candidate_ids) do
    visible_candidate_ids = MapSet.new(visible_candidate_ids(candidates))

    checked_candidate_ids
    |> MapSet.intersection(visible_candidate_ids)
    |> normalize_checked_candidate_selection_mode(candidates)
  end

  defp normalize_checked_candidate_selection_mode(checked_candidate_ids, candidates) do
    case selection_mode(candidates, checked_candidate_ids) do
      :mixed ->
        # Refreshes and future query-param changes can invalidate part of the
        # checked set. If mixed states sneak in, keep only the first visible
        # state we encounter so bulk behavior stays same-state only.
        candidates
        |> Enum.reduce({MapSet.new(), nil}, fn candidate, {normalized_ids, chosen_mode} ->
          if candidate_checked?(candidate, checked_candidate_ids) do
            candidate_mode = candidate_state(candidate)

            cond do
              is_nil(chosen_mode) ->
                {MapSet.put(normalized_ids, candidate.activity_resource_id), candidate_mode}

              chosen_mode == candidate_mode ->
                {MapSet.put(normalized_ids, candidate.activity_resource_id), chosen_mode}

              true ->
                {normalized_ids, chosen_mode}
            end
          else
            {normalized_ids, chosen_mode}
          end
        end)
        |> elem(0)

      _selection_mode ->
        checked_candidate_ids
    end
  end

  defp visible_candidate_ids(candidates) do
    Enum.map(candidates, & &1.activity_resource_id)
  end

  # The bulk-selection mode is derived from the checked rows in the current
  # query result. `:mixed` is a defensive state that can appear transiently
  # during refresh/normalization, but the UI should settle back to one state.
  defp selection_mode(candidates, checked_candidate_ids) do
    # Fold once so we do not build the intermediate checked-candidate/state lists
    # on every render and checkbox event.
    candidates
    |> Enum.reduce(:none, fn candidate, mode ->
      if candidate_checked?(candidate, checked_candidate_ids) do
        candidate_mode = candidate_state(candidate)

        case mode do
          :none -> candidate_mode
          ^candidate_mode -> mode
          _ -> :mixed
        end
      else
        mode
      end
    end)
  end

  defp bulk_selection_active?(checked_candidate_ids), do: MapSet.size(checked_candidate_ids) > 0

  defp bulk_selection_view_state(candidates, checked_candidate_ids) do
    selection_mode = selection_mode(candidates, checked_candidate_ids)
    selectable_candidate_ids = selectable_visible_candidate_ids(candidates, selection_mode)
    count = MapSet.size(checked_candidate_ids)
    action = bulk_selection_action(selection_mode)

    # The template asks "is this row selectable?" several times per candidate.
    # Precomputing a lookup keeps those checks O(1) and avoids repeated scans.
    selectable_candidate_lookup =
      Map.new(selectable_candidate_ids, fn candidate_id -> {candidate_id, true} end)

    %{
      selection_mode: selection_mode,
      active?: count > 0,
      action: action,
      action_label: bulk_selection_action_label(action, count),
      button_classes: bulk_selection_action_button_classes(action),
      all_selectable_checked?:
        all_selectable_candidates_checked?(candidates, checked_candidate_ids),
      selectable_candidate_lookup: selectable_candidate_lookup
    }
  end

  defp selectable_visible_candidate_ids(candidates, selection_mode) do
    case selection_mode do
      :none ->
        visible_candidate_ids(candidates)

      :mixed ->
        []

      active_selection_mode ->
        candidates
        |> Enum.filter(&(candidate_state(&1) == active_selection_mode))
        |> visible_candidate_ids()
    end
  end

  defp bulk_selection_action(selection_mode) do
    case selection_mode do
      :available -> :remove
      :removed -> :restore
      _ -> nil
    end
  end

  defp bulk_selection_action_label(action, count) do
    case action do
      :remove -> "Remove Selected (#{count})"
      :restore -> "Restore Selected (#{count})"
      nil -> nil
    end
  end

  defp bulk_selection_action_button_classes(action) do
    shared =
      "inline-flex items-center gap-2 rounded-[6px] border bg-Surface-surface-primary px-4 py-2 font-open-sans text-[14px] font-semibold leading-4 tracking-normal shadow-[0px_2px_4px_rgba(0,52,99,0.10)] transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"

    case action do
      :remove ->
        "#{shared} border-Border-border-danger text-Specially-Tokens-Text-text-button-pill-muted focus-visible:outline-Border-border-danger"

      :restore ->
        "#{shared} bg-transparent border-[#8AB8E5] text-Text-text-button focus-visible:outline-[#8AB8E5]"

      nil ->
        shared
    end
  end

  defp preview_shell_state_key(candidates, checked_candidate_ids) do
    "#{selection_mode(candidates, checked_candidate_ids)}-#{MapSet.size(checked_candidate_ids)}"
  end

  defp master_selectable_candidate_ids(candidates, checked_candidate_ids) do
    master_selection_mode = master_selection_mode(candidates, checked_candidate_ids)

    candidates
    |> Enum.filter(&selectable_candidate?(&1, master_selection_mode))
    |> visible_candidate_ids()
  end

  defp master_selection_mode(candidates, checked_candidate_ids) do
    case selection_mode(candidates, checked_candidate_ids) do
      :none -> preferred_master_selection_mode(candidates)
      active_selection_mode -> active_selection_mode
    end
  end

  defp preferred_master_selection_mode(candidates) do
    cond do
      Enum.any?(candidates, &(candidate_state(&1) == :available)) -> :available
      Enum.any?(candidates, &(candidate_state(&1) == :removed)) -> :removed
      true -> :none
    end
  end

  defp selectable_candidate?(_candidate, :none), do: true
  defp selectable_candidate?(_candidate, :mixed), do: false

  defp selectable_candidate?(candidate, active_selection_mode) do
    candidate_state(candidate) == active_selection_mode
  end

  defp candidate_state(%{enabled?: true}), do: :available
  defp candidate_state(%{enabled?: false}), do: :removed

  defp candidate_checked?(candidate, checked_candidate_ids) do
    MapSet.member?(checked_candidate_ids, candidate.activity_resource_id)
  end

  defp all_selectable_candidates_checked?([], _checked_candidate_ids), do: false

  defp all_selectable_candidates_checked?(candidates, checked_candidate_ids) do
    selectable_candidate_ids =
      master_selectable_candidate_ids(candidates, checked_candidate_ids)

    selectable_candidate_ids != [] and
      Enum.all?(selectable_candidate_ids, &MapSet.member?(checked_candidate_ids, &1))
  end

  defp remaining_candidate_count(total_candidate_count, candidates) do
    max(total_candidate_count - length(candidates), 0)
  end

  defp candidate_empty_state_message(candidate_filters) do
    if candidate_filters_active?(candidate_filters) do
      "No questions match the selected filters."
    else
      "No matching questions are currently available for this activity bank selection."
    end
  end

  defp candidate_filters_active?(%{
         visibility: visibility,
         text_search: text_search,
         activity_type_ids: activity_type_ids,
         objective_ids: objective_ids
       }) do
    visibility != :all or text_search != "" or activity_type_ids != [] or objective_ids != []
  end

  defp default_candidate_filters do
    %{visibility: :all, text_search: "", activity_type_ids: [], objective_ids: []}
  end

  defp candidate_filter_label(label, []), do: label
  defp candidate_filter_label(label, selected_ids), do: "#{label} (#{length(selected_ids)})"

  defp candidate_filters_from_params(params, current_filters) do
    %{
      visibility:
        params
        |> Map.get("visibility", current_filters.visibility)
        |> candidate_visibility_from_param(),
      text_search: candidate_text_search_from_params(params, current_filters.text_search),
      activity_type_ids:
        candidate_filter_ids_from_params(
          params,
          "activity_type_ids",
          current_filters.activity_type_ids
        ),
      objective_ids:
        candidate_filter_ids_from_params(params, "objective_ids", current_filters.objective_ids)
    }
  end

  defp candidate_visibility_from_param(visibility)
       when visibility in [:all, :available, :removed],
       do: visibility

  defp candidate_visibility_from_param("available"), do: :available
  defp candidate_visibility_from_param("removed"), do: :removed
  defp candidate_visibility_from_param(_visibility), do: :all

  defp candidate_text_search_from_params(params, current_text_search) do
    case Map.fetch(params, "text_search") do
      {:ok, value} when is_binary(value) -> normalize_candidate_text_search(value)
      {:ok, _value} -> ""
      :error -> current_text_search
    end
  end

  defp normalize_candidate_text_search(value) do
    value
    |> String.trim()
    |> String.slice(0, @candidate_text_search_max_length)
  end

  defp candidate_filter_ids_from_params(params, key, current_ids) do
    case Map.fetch(params, key) do
      {:ok, value} -> parse_candidate_filter_ids(value)
      :error -> current_ids
    end
  end

  defp parse_candidate_filter_ids(value) do
    value
    |> List.wrap()
    |> Enum.flat_map(fn value ->
      value
      |> to_string()
      |> String.split(",", trim: true)
    end)
    |> Enum.reduce([], fn value, acc ->
      case Integer.parse(value) do
        {id, ""} when id > 0 -> [id | acc]
        _ -> acc
      end
    end)
    |> Enum.reverse()
    |> Enum.uniq()
  end

  defp candidate_selected?(candidate, selected_candidate_id) do
    candidate.activity_resource_id == selected_candidate_id
  end

  defp candidate_row_classes(
         candidate,
         selected_candidate_id,
         selectable?,
         bulk_selection_active?
       ) do
    selected? = candidate_selected?(candidate, selected_candidate_id)

    [
      "grid w-full grid-cols-[28px_minmax(0,1fr)] shrink-0 items-center gap-2 border-b border-Table-table-border p-2.5 text-left transition focus:outline-none focus-visible:ring-2 focus-visible:ring-Fill-Buttons-fill-primary",
      if(selected?,
        do: "bg-Table-table-select",
        else: "bg-Surface-surface-primary hover:bg-Surface-surface-secondary-hover"
      ),
      if(!candidate.enabled?,
        do: "bg-Surface-surface-secondary-muted opacity-60 h-[88px]",
        else: "h-12"
      ),
      if(bulk_selection_active? and !selectable?, do: "opacity-50", else: nil)
    ]
  end

  defp invalid_remove_warning_assigns(count, active_candidates, removal_count, warning) do
    %{
      warning: warning,
      title: invalid_remove_warning_title(removal_count),
      count: count,
      active_candidates: active_candidates,
      keep_label: invalid_remove_warning_keep_label(removal_count),
      removal_subject: invalid_remove_warning_subject(removal_count),
      target: Map.get(warning, :target) || Map.get(warning, "target")
    }
  end

  defp invalid_remove_warning_title(1), do: "Cannot remove this question"
  defp invalid_remove_warning_title(_count), do: "Cannot remove these questions"

  defp invalid_remove_warning_keep_label(1), do: "Keep question"
  defp invalid_remove_warning_keep_label(_count), do: "Keep questions"

  defp invalid_remove_warning_subject(1), do: "this question"
  defp invalid_remove_warning_subject(count), do: "these #{count} questions"

  defp question_word(1), do: "question"
  defp question_word(_count), do: "questions"

  defp navigation_params(params, section_slug) do
    %{}
    |> maybe_put_sanitized_navigation_param("return_to", params["return_to"], section_slug)
    |> maybe_put_sanitized_navigation_param("request_path", params["request_path"], section_slug)
  end

  defp adaptive_redirect_params(params) do
    section_slug = params["section_slug"]

    []
    |> maybe_put_adaptive_redirect_param(:return_to, params["return_to"], section_slug)
    |> maybe_put_adaptive_redirect_param(:request_path, params["request_path"], section_slug)
  end

  defp maybe_put_sanitized_navigation_param(navigation_params, _key, value, _section_slug)
       when value in [nil, ""] do
    navigation_params
  end

  defp maybe_put_sanitized_navigation_param(navigation_params, key, value, section_slug)
       when is_binary(value) do
    case PreviewReturn.sanitize_return_to(value, section_slug) do
      ^value -> Map.put(navigation_params, key, value)
      _fallback -> navigation_params
    end
  end

  defp maybe_put_sanitized_navigation_param(navigation_params, _key, _value, _section_slug),
    do: navigation_params

  defp maybe_put_adaptive_redirect_param(params, _key, value, _section_slug)
       when value in [nil, ""] do
    params
  end

  defp maybe_put_adaptive_redirect_param(params, key, value, section_slug)
       when is_binary(value) and is_binary(section_slug) do
    case PreviewReturn.sanitize_return_to(value, section_slug) do
      ^value -> Keyword.put(params, key, value)
      _fallback -> params
    end
  end

  defp maybe_put_adaptive_redirect_param(params, _key, _value, _section_slug), do: params

  defp local_back_path(section_slug, revision_slug, navigation_params) do
    case Map.get(navigation_params, "request_path") do
      path when is_binary(path) and path != "" ->
        path

      _ ->
        PreviewRoutes.lesson_path(section_slug, revision_slug, navigation_params)
    end
  end

  defp preview_sidebar_state(params) do
    case Map.get(params, "sidebar_expanded") do
      "false" ->
        false

      "true" ->
        true

      _ ->
        case params["return_to"] || params["request_path"] do
          path when is_binary(path) ->
            sidebar_expanded_from_path(path)

          _ ->
            true
        end
    end
  end

  defp sidebar_expanded_from_path(path) when is_binary(path) do
    case URI.parse(path) do
      %URI{query: query} when is_binary(query) and query != "" ->
        query_params = Plug.Conn.Query.decode(query)

        case Map.get(query_params, "sidebar_expanded") do
          "false" -> false
          _ -> true
        end

      _ ->
        true
    end
  end

  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> parsed
      _ -> nil
    end
  end

  defp parse_integer(_value), do: nil

  # Selection-level settings come from the authored bank-selection node itself, not from the
  # candidate activity revisions. Authoring exposes this as `pointsPerActivity`, and delivery
  # normalizes it with the same default of 1 when the key is absent.
  defp selection_points_per_question(%{"pointsPerActivity" => points})
       when is_integer(points) and points > 0,
       do: points

  defp selection_points_per_question(_selection), do: 1
end
