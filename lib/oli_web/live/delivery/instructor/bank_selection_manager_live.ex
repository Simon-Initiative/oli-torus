defmodule OliWeb.Delivery.Instructor.BankSelectionManagerLive do
  use OliWeb, :live_view

  alias Oli.Activities
  alias Oli.Delivery.InstructorCustomizations
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing.DeliveryResolver, as: Resolver
  alias Oli.Resources.Revision
  alias OliWeb.Delivery.Instructor.PreviewPageContext
  alias OliWeb.Components.Delivery.Layouts
  alias OliWeb.Delivery.Instructor.{PreviewReturn, PreviewRoutes}
  alias OliWeb.Icons
  alias OliWeb.ManualGrading.RenderedActivity

  @candidate_row_limit 25

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
             PreviewRoutes.page_path(
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

        candidate_surface_script_sources_by_activity_type_id =
          candidate_surface_script_sources_by_activity_type_id()

        case load_candidates(section, revision, selection) do
          {:ok, candidate_page} ->
            preview_script_sources =
              candidate_surface_script_sources_for_selection(
                section,
                revision,
                selection,
                candidate_page.total_count,
                candidate_surface_script_sources_by_activity_type_id
              )

            {:ok,
             socket
             |> assign(
               page_revision: revision,
               current_page_resource_id: revision.resource_id,
               selection: selection,
               selection_id: selection_id,
               selection_points_per_question: selection_points_per_question(selection),
               selection_criteria_rows: selection_criteria_rows(section.slug, selection),
               navigation_params: navigation_params,
               sidebar_expanded: sidebar_expanded,
               request_path: local_back_path(section.slug, revision.slug, navigation_params),
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

    if Enum.any?(socket.assigns.candidates, &(&1.activity_resource_id == candidate_id)) do
      {:noreply,
       update(
         socket,
         :checked_candidate_ids,
         &toggle_checked_candidate_id(&1, candidate_id)
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_all_candidate_checkboxes", _params, socket) do
    checked_candidate_ids =
      if all_visible_candidates_checked?(
           socket.assigns.candidates,
           socket.assigns.checked_candidate_ids
         ) do
        Enum.reduce(
          visible_candidate_ids(socket.assigns.candidates),
          socket.assigns.checked_candidate_ids,
          fn id, acc ->
            MapSet.delete(acc, id)
          end
        )
      else
        Enum.reduce(
          visible_candidate_ids(socket.assigns.candidates),
          socket.assigns.checked_candidate_ids,
          fn id, acc ->
            MapSet.put(acc, id)
          end
        )
      end

    {:noreply, assign(socket, :checked_candidate_ids, checked_candidate_ids)}
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
      candidate_offset: candidate_offset
    } = socket.assigns

    case load_candidates(section, page_revision, selection, offset: candidate_offset) do
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
    section = socket.assigns.section
    actor = socket.assigns.current_user

    target = %{
      kind: "bank_candidate",
      pageResourceId: page_resource_id,
      selectionId: selection_id,
      activityResourceId: activity_resource_id
    }

    current_page_resource_id = socket.assigns.current_page_resource_id
    current_selection_id = socket.assigns.selection_id

    valid_activity_ids =
      MapSet.new(Enum.map(socket.assigns.candidates, & &1.activity_resource_id))

    result =
      cond do
        page_resource_id != current_page_resource_id ->
          {:error, :invalid_page_target}

        selection_id != current_selection_id ->
          {:error, :invalid_selection_target}

        not MapSet.member?(valid_activity_ids, activity_resource_id) ->
          {:error, :invalid_activity_target}

        true ->
          case action do
            "remove" ->
              InstructorCustomizations.exclude_bank_candidate(
                section,
                page_resource_id,
                selection_id,
                activity_resource_id,
                actor: actor
              )

            "restore" ->
              InstructorCustomizations.restore_bank_candidate(
                section,
                page_resource_id,
                selection_id,
                activity_resource_id,
                actor: actor
              )

            _ ->
              {:error, {:invalid_action, action}}
          end
      end

    case result do
      {:ok, _exclusion_view} ->
        active_available_count =
          if action == "remove" do
            max(socket.assigns.active_available_count - 1, 0)
          else
            socket.assigns.active_available_count + 1
          end

        candidates =
          update_candidate_customization_state(
            socket.assigns.candidates,
            activity_resource_id,
            action,
            active_available_count,
            socket.assigns.selection_count
          )

        reply = %{
          ok: true,
          target: target,
          activityResourceId: activity_resource_id,
          visualState: "default",
          statusPill: nil,
          actions:
            if(action == "remove",
              do: [%{kind: "restore", label: "Restore"}],
              else: [%{kind: "remove", label: "Remove"}]
            )
        }

        socket =
          socket
          |> assign(:candidates, candidates)
          |> assign(:active_available_count, active_available_count)
          |> maybe_refresh_selected_candidate_preview(activity_resource_id)
          |> put_flash(
            :info,
            if(action == "remove",
              do: "Question removed from this activity bank selection.",
              else: "Question restored to this activity bank selection."
            )
          )

        {:reply, reply, socket}

      {:error, {:unauthorized, :customize_section}} ->
        reply = %{ok: false, target: target}

        socket =
          put_flash(socket, :error, "You are not allowed to customize this activity bank.")

        {:reply, reply, socket}

      {:error, :invalid_page_target} ->
        reply = %{ok: false, target: target}

        socket =
          put_flash(
            socket,
            :error,
            "Unable to update a question outside this activity bank manager."
          )

        {:reply, reply, socket}

      {:error, :invalid_selection_target} ->
        reply = %{ok: false, target: target}

        socket =
          put_flash(
            socket,
            :error,
            "Unable to update a question outside the current activity bank selection."
          )

        {:reply, reply, socket}

      {:error, :invalid_activity_target} ->
        reply = %{ok: false, target: target}

        socket =
          put_flash(socket, :error, "Unable to update a question that is not in this list.")

        {:reply, reply, socket}

      {:error, _reason} ->
        reply = %{ok: false, target: target}

        socket = put_flash(socket, :error, "Unable to update this activity bank question.")

        {:reply, reply, socket}
    end
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

                <div class="mt-5 space-y-2.5 text-sm leading-4 text-Text-text-low">
                  <div class="font-bold text-Text-text-high">Selection criteria:</div>
                  <div :for={row <- @selection_criteria_rows} class="space-y-2">
                    <div class="text-Text-text-low-alpha text-sm font-bold leading-4">
                      {row.label}
                    </div>
                    <div class="bg-Specially-Tokens-Fill-fill-input-focused rounded-md px-2.5 py-2 text-Text-text-high text-base font-semibold leading-6">
                      {row.value}
                    </div>
                  </div>
                </div>
              </header>

              <div class="mt-10">
                <div class="mt-4 text-sm font-normaltext-gray-500 leading-5">
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
                        checked={all_visible_candidates_checked?(@candidates, @checked_candidate_ids)}
                        phx-click="toggle_all_candidate_checkboxes"
                        class="h-4 w-4 rounded-[2px] border-Border-border-default text-Fill-Buttons-fill-primary focus:ring-Fill-Buttons-fill-primary"
                      />
                      <span>Question</span>
                    </div>

                    <div class="flex flex-col h-[calc(100vh-300px)] overflow-scroll">
                      <div
                        :for={candidate <- @candidates}
                        id={"candidate-row-#{candidate.activity_resource_id}"}
                        role="option"
                        aria-selected={candidate_selected?(candidate, @selected_candidate_id)}
                        data-candidate-enabled={to_string(candidate.enabled?)}
                        class={candidate_row_classes(candidate, @selected_candidate_id)}
                      >
                        <input
                          id={"candidate-checkbox-#{candidate.activity_resource_id}"}
                          type="checkbox"
                          aria-label={"Select #{candidate.title}"}
                          checked={candidate_checked?(candidate, @checked_candidate_ids)}
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
                        id={"selected-candidate-preview-shell-#{candidate.activity_resource_id}"}
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
                      No matching questions are currently available for this activity bank selection.
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

    socket
    |> assign(
      candidates: candidates,
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
    candidates =
      socket.assigns.candidates ++
        Enum.reject(candidate_page.candidates, fn appended ->
          Enum.any?(
            socket.assigns.candidates,
            &(&1.activity_resource_id == appended.activity_resource_id)
          )
        end)

    socket
    |> assign(
      candidates: candidates,
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

  defp load_candidates(%Section{} = section, %Revision{} = page_revision, selection, opts \\ []) do
    InstructorCustomizations.list_bank_selection_candidates(
      section,
      page_revision,
      selection,
      Keyword.put_new(opts, :limit, @candidate_row_limit)
    )
  end

  defp default_selected_candidate_id([candidate | _]), do: candidate.activity_resource_id
  defp default_selected_candidate_id([]), do: nil

  defp assign_selected_candidate_preview(socket) do
    case selected_candidate(socket.assigns.candidates, socket.assigns.selected_candidate_id) do
      nil ->
        assign(socket, :selected_candidate_preview_html, nil)

      candidate ->
        with %Revision{} = activity_revision <-
               Resolver.from_resource_id(
                 socket.assigns.section.slug,
                 candidate.activity_resource_id
               ),
             {:ok, %{html: html}} <-
               PreviewPageContext.build_bank_candidate_preview(
                 socket.assigns.section,
                 socket.assigns.page_revision,
                 activity_revision,
                 selection_id: socket.assigns.selection_id,
                 can_customize?: true,
                 actions: candidate_preview_actions(candidate)
               ) do
          assign(socket, :selected_candidate_preview_html, html)
        else
          _ ->
            assign(socket, :selected_candidate_preview_html, nil)
        end
    end
  end

  # The preview card updates its button immediately from the LiveView reply, but the
  # server-side HTML for the currently selected candidate must stay in sync as well.
  # Otherwise any later patch/remount (for example, after clearing a flash) can recreate
  # the selected preview from stale HTML and revert Remove/Restore locally.
  defp maybe_refresh_selected_candidate_preview(socket, activity_resource_id)
       when socket.assigns.selected_candidate_id == activity_resource_id do
    assign_selected_candidate_preview(socket)
  end

  defp maybe_refresh_selected_candidate_preview(socket, _activity_resource_id), do: socket

  defp candidate_preview_actions(candidate) do
    if candidate.enabled? do
      [%{kind: "remove", label: "Remove"}]
    else
      [%{kind: "restore", label: "Restore"}]
    end
  end

  # Each activity type contributes whichever script the instructor-preview surface actually
  # needs: preview JS for types with dedicated preview support, or authoring JS for the
  # fallback path used by activity types that are not yet preview-capable (see Oli.Activities.preview_supported_activity_slug?).
  defp candidate_surface_script_sources_by_activity_type_id do
    Activities.list_activity_registrations()
    |> Enum.reduce(%{}, fn activity_type, acc ->
      case PreviewPageContext.preview_script_for_registration(activity_type) do
        nil -> acc
        script -> Map.put(acc, activity_type.id, "/js/#{script}")
      end
    end)
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

  defp update_candidate_customization_state(
         candidates,
         activity_resource_id,
         action,
         active_available_count,
         selection_count
       ) do
    Enum.map(candidates, fn candidate ->
      enabled? =
        cond do
          candidate.activity_resource_id == activity_resource_id and action == "remove" -> false
          candidate.activity_resource_id == activity_resource_id and action == "restore" -> true
          true -> candidate.enabled?
        end

      %{
        candidate
        | enabled?: enabled?,
          disable_allowed?: !enabled? or active_available_count > selection_count
      }
    end)
  end

  defp selected_candidate(candidates, selected_candidate_id) do
    Enum.find(candidates, &(&1.activity_resource_id == selected_candidate_id))
  end

  defp toggle_checked_candidate_id(checked_candidate_ids, candidate_id) do
    if MapSet.member?(checked_candidate_ids, candidate_id) do
      MapSet.delete(checked_candidate_ids, candidate_id)
    else
      MapSet.put(checked_candidate_ids, candidate_id)
    end
  end

  defp normalize_checked_candidate_ids(candidates, checked_candidate_ids) do
    visible_candidate_ids = MapSet.new(visible_candidate_ids(candidates))

    MapSet.intersection(checked_candidate_ids, visible_candidate_ids)
  end

  defp visible_candidate_ids(candidates) do
    Enum.map(candidates, & &1.activity_resource_id)
  end

  defp candidate_checked?(candidate, checked_candidate_ids) do
    MapSet.member?(checked_candidate_ids, candidate.activity_resource_id)
  end

  defp all_visible_candidates_checked?([], _checked_candidate_ids), do: false

  defp all_visible_candidates_checked?(candidates, checked_candidate_ids) do
    Enum.all?(candidates, &candidate_checked?(&1, checked_candidate_ids))
  end

  defp remaining_candidate_count(total_candidate_count, candidates) do
    max(total_candidate_count - length(candidates), 0)
  end

  defp candidate_selected?(candidate, selected_candidate_id) do
    candidate.activity_resource_id == selected_candidate_id
  end

  defp candidate_row_classes(candidate, selected_candidate_id) do
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
      )
    ]
  end

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

  defp sidebar_expanded_from_path(_), do: true

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

  # Selection criteria can combine tags, learning objectives, activity type, and text expressions.
  # We keep the summary local to this LiveView so the manager can show authored criteria without
  # introducing a separate presentation layer just for this ticket.
  defp selection_criteria_rows(_section_slug, %{"logic" => %{"conditions" => nil}}),
    do: [%{label: "All questions", value: "No additional filters"}]

  defp selection_criteria_rows(section_slug, %{"logic" => %{"conditions" => conditions}})
       when is_map(conditions) do
    title_map = selection_resource_titles(section_slug, conditions)
    activity_type_titles = activity_type_titles()

    selection_condition_rows(conditions, title_map, activity_type_titles)
  end

  defp selection_criteria_rows(_section_slug, _selection),
    do: [%{label: "All questions", value: "No additional filters"}]

  defp selection_condition_rows(
         %{"children" => children, "operator" => operator},
         title_map,
         activity_type_titles
       )
       when is_list(children) do
    child_rows =
      Enum.flat_map(children, &selection_condition_rows(&1, title_map, activity_type_titles))

    if child_rows == [] do
      [%{label: "Selection logic", value: logical_operator_label(operator)}]
    else
      Enum.with_index(child_rows, 1)
      |> Enum.map(fn {row, index} ->
        %{label: "#{logical_operator_label(operator)} #{index}: #{row.label}", value: row.value}
      end)
    end
  end

  defp selection_condition_rows(
         %{"fact" => fact, "operator" => operator, "value" => value},
         title_map,
         activity_type_titles
       ) do
    [
      %{
        label: criteria_label(fact),
        value: criteria_value(fact, operator, value, title_map, activity_type_titles)
      }
    ]
  end

  defp selection_condition_rows(_conditions, _title_map, _activity_type_titles), do: []

  defp selection_resource_titles(section_slug, conditions) do
    resource_ids =
      collect_selection_resource_ids(conditions)
      |> Enum.uniq()

    if resource_ids == [] do
      %{}
    else
      # Criteria ids are authored into the published selection, so resolve them through the
      # current section slug instead of the mutable authoring project boundary.
      Resolver.from_resource_id(section_slug, resource_ids)
      |> Enum.reject(&is_nil/1)
      |> Map.new(fn revision -> {revision.resource_id, revision.title} end)
    end
  end

  defp collect_selection_resource_ids(%{"children" => children}) when is_list(children) do
    Enum.flat_map(children, &collect_selection_resource_ids/1)
  end

  defp collect_selection_resource_ids(%{"fact" => fact, "value" => value})
       when fact in ["tags", "objectives"] and is_list(value),
       do: value

  defp collect_selection_resource_ids(%{"conditions" => conditions}) when is_map(conditions),
    do: collect_selection_resource_ids(conditions)

  defp collect_selection_resource_ids(_), do: []

  defp activity_type_titles do
    Activities.list_activity_registrations()
    |> Map.new(fn registration -> {registration.id, registration.title} end)
  end

  defp criteria_label("tags"), do: "Tags:"
  defp criteria_label("objectives"), do: "Learning objectives:"
  defp criteria_label("type"), do: "Question type:"
  defp criteria_label("text"), do: "Activity content:"
  defp criteria_label(_fact), do: "Selection rule:"

  defp criteria_value("tags", operator, value, title_map, _activity_type_titles),
    do: prefixed_criteria_value(operator, map_titles(value, title_map))

  defp criteria_value("objectives", operator, value, title_map, _activity_type_titles),
    do: prefixed_criteria_value(operator, map_titles(value, title_map))

  defp criteria_value("type", operator, value, _title_map, activity_type_titles),
    do: prefixed_criteria_value(operator, map_type_titles(value, activity_type_titles))

  defp criteria_value("text", operator, value, _title_map, _activity_type_titles)
       when is_binary(value),
       do: prefixed_criteria_value(operator, value)

  defp criteria_value(_fact, operator, value, _title_map, _activity_type_titles),
    do: prefixed_criteria_value(operator, inspect(value))

  defp prefixed_criteria_value(operator, text) do
    prefix =
      case operator do
        "contains" -> "Contains "
        "does_not_contain" -> "Does not contain "
        "equals" -> "Equals "
        "does_not_equal" -> "Does not equal "
        _ -> ""
      end

    prefix <> text
  end

  defp map_titles(values, title_map) when is_list(values) do
    values
    |> Enum.map(fn id -> Map.get(title_map, id, to_string(id)) end)
    |> Enum.join(", ")
  end

  defp map_titles(value, _title_map), do: to_string(value)

  defp map_type_titles(values, activity_type_titles) when is_list(values) do
    values
    |> Enum.map(fn id -> Map.get(activity_type_titles, id, to_string(id)) end)
    |> Enum.join(", ")
  end

  defp map_type_titles(value, _activity_type_titles), do: to_string(value)

  defp logical_operator_label("all"), do: "All of"
  defp logical_operator_label("any"), do: "Any of"
  defp logical_operator_label(_operator), do: "Selection logic"
end
