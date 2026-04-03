defmodule OliWeb.ManualGrading.ManualGradingView do
  @moduledoc """
  Implements instructor manual scoring of those activity attempts that are in a "submitted"
  state.

  Allows "point" based scoring, where the maximum possible points can be driven from the part specification
  of an activity via the "out_of" attribute.  This optional attribute of a part, if not specified, defaults
  to `nil`, which this view interprets as the value of 1.

  This view allows a user to navigate through the items that are awaiting scoring, and to enter scores
  and feedback, but not actually apply these changes.  This "temporary" state is ephemeral in the sense that
  it is scoped to this view only as it is simply held in a state attribute of this view (`score_feedbacks`).
  We can consider expanding the functionality here by having this "temporary" state be stored directly in the
  part attempt.  That would enable a user to visit this view, enter feedback and scores for a student (but not
  apply them) and then navigate away, return to the view and still see that work.

  """

  use OliWeb, :live_view

  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{TextSearch, PagedTable, Breadcrumb}
  alias Oli.Activities.Model.Part
  alias Oli.Delivery.Attempts.ManualGrading
  alias Oli.Delivery.Attempts.ManualGrading.BrowseOptions
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes
  import OliWeb.DelegatedEvents
  import OliWeb.Common.Params
  alias OliWeb.Sections.Mount
  alias Oli.Delivery.Attempts.Core
  alias OliWeb.ManualGrading.TableModel
  alias OliWeb.ManualGrading.RenderedActivity
  alias OliWeb.ManualGrading.SelectedSubmission
  alias OliWeb.ManualGrading.SelectedSubmissionBuilder
  alias OliWeb.ManualGrading.Filters
  alias OliWeb.ManualGrading.Tabs
  alias OliWeb.ManualGrading.ScoreFeedback
  alias OliWeb.ManualGrading.Group
  alias OliWeb.ManualGrading.PartScoring
  alias OliWeb.ManualGrading.Apply

  @limit 10
  @default_options %BrowseOptions{
    user_id: nil,
    activity_id: nil,
    page_id: nil,
    graded: nil,
    text_search: nil
  }

  def set_breadcrumbs(type, section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(type, section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Manual Scoring",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(%{"section_slug" => section_slug}, _session, socket) do
    case Mount.for(section_slug, socket) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, _, section} ->
        attempts =
          ManualGrading.browse_submitted_attempts(
            section,
            %Paging{offset: 0, limit: @limit},
            %Sorting{direction: :desc, field: :date_submitted},
            @default_options
          )

        total_count = determine_total(attempts)

        activities = Oli.Activities.list_activity_registrations()
        part_components = Oli.PartComponents.get_part_component_scripts(:delivery_script)

        additional_scripts =
          Enum.map(activities, fn a -> a.authoring_script end) |> Enum.concat(part_components)

        activity_types_map = Enum.reduce(activities, %{}, fn e, m -> Map.put(m, e.id, e) end)

        ctx = socket.assigns.ctx
        {:ok, table_model} = TableModel.new(attempts, activity_types_map, ctx)

        table_model =
          Map.put(table_model, :sort_order, :desc)
          |> Map.put(:sort_by_spec, TableModel.date_submitted_spec())

        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(type, section),
           section: section,
           total_count: total_count,
           table_model: table_model,
           additional_scripts: additional_scripts,
           options: @default_options,
           activity_types_map: activity_types_map,
           title: "Manual Scoring",
           offset: 0,
           limit: @limit,
           active_tab: :review,
           score_feedbacks: %{}
         )}
    end
  end

  defp determine_total(projects) do
    case(projects) do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end

  defp is_apply_transition?(params) do
    selected = get_param(params, "selected", nil)

    cond do
      is_nil(selected) -> false
      selected == "none" -> true
      selected == "0" -> true
      String.starts_with?(selected, "-") -> true
      true -> false
    end
  end

  def handle_params(params, _, socket) do
    if is_apply_transition?(params) do
      handle_transition_after_apply(params, socket)
    else
      handle_regular_param_update(params, socket)
    end
  end

  # After a score has been applied, special handling of the "selected" key
  # in the params update exists.  This "selected" key normally contains the
  # literal database Id of the attempt that is selected.  In this case, however,
  # "selected" contains the index within the page that is about to be returned
  # of the item to select next.  This index is encoded as a negative number so
  # that this impl can distinguish it between Id references.  We need to encode
  # the index because there are cases where we do not know the exact attempt that should
  # be next 'selected'.  Consider the case that 11 attempts exist, and attempts 1
  # through 10 are displayed in the first page.  If the user has selected item 10
  # (the last item in this page) and applies scoring, the next item that should be
  # selected is item 11, which then should also appear as the new, last item in the
  # first page. However, we don't know what that attempt at the time that this
  # param update is patched.  This "index" mode allows the view to basically operate in
  # a "just select the next item that appears in this index after the query is rerun"
  # mode.
  defp handle_transition_after_apply(params, socket) do
    selected = get_param(params, "selected", nil)

    table_model =
      SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    offset = get_int_param(params, "offset", 0)

    options = %BrowseOptions{
      text_search: get_param(params, "text_search", ""),
      user_id: get_int_param(params, "user_id", nil),
      activity_id: get_int_param(params, "activity_id", nil),
      page_id: get_int_param(params, "page_id", nil),
      graded: get_boolean_param(params, "graded", nil)
    }

    attempts =
      ManualGrading.browse_submitted_attempts(
        socket.assigns.section,
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )

    selected =
      case selected do
        "none" ->
          nil

        n ->
          index = String.to_integer(n) * -1

          case Enum.at(attempts, index) do
            nil -> nil
            item -> item.id |> Integer.to_string()
          end
      end

    table_model =
      Map.put(table_model, :rows, attempts)
      |> Map.put(:selected, selected)

    total_count = determine_total(attempts)

    {:noreply,
     assign(
       socket,
       offset: offset,
       table_model: table_model,
       total_count: total_count,
       options: options
     )
     |> assign(build_state_for_selection(table_model, socket.assigns))}
  end

  defp handle_regular_param_update(params, socket) do
    selected = get_param(params, "selected", nil)

    table_model =
      SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    offset = get_int_param(params, "offset", 0)
    table_model = Map.put(table_model, :selected, selected)

    options = %BrowseOptions{
      text_search: get_param(params, "text_search", ""),
      user_id: get_int_param(params, "user_id", nil),
      activity_id: get_int_param(params, "activity_id", nil),
      page_id: get_int_param(params, "page_id", nil),
      graded: get_boolean_param(params, "graded", nil)
    }

    # This is an optimization, if the only thing that has changed is the selection
    # we do not need to re-run the query.  Just update the selected attempt.
    if only_selection_changed(socket.assigns, table_model, options, offset) do
      table_model = Map.put(socket.assigns.table_model, :selected, selected)

      {:noreply,
       assign(
         socket,
         table_model: table_model
       )
       |> assign(build_state_for_selection(table_model, socket.assigns))}
    else
      attempts =
        ManualGrading.browse_submitted_attempts(
          socket.assigns.section,
          %Paging{offset: offset, limit: @limit},
          %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
          options
        )

      selected =
        case Enum.find(attempts, fn r -> Integer.to_string(r.id) == selected end) do
          nil -> nil
          attempt -> attempt.id |> Integer.to_string()
        end

      table_model =
        Map.put(table_model, :rows, attempts)
        |> Map.put(:selected, selected)

      total_count = determine_total(attempts)

      {:noreply,
       assign(
         socket,
         offset: offset,
         table_model: table_model,
         total_count: total_count,
         options: options
       )
       |> assign(build_state_for_selection(table_model, socket.assigns))}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto">
      <%= for script <- @additional_scripts do %>
        <script type="text/javascript" src={Routes.static_path(OliWeb.Endpoint, "/js/" <> script)}>
        </script>
      <% end %>

      <Group.render>
        <div class="d-flex justify-content-between">
          <TextSearch.render id="text-search" />
          <Filters.render options={@options} selection={!is_nil(@attempt)} />
        </div>

        <div class="mb-3" />

        <PagedTable.render
          allow_selection={true}
          filter={@options.text_search}
          table_model={@table_model}
          total_count={@total_count}
          offset={@offset}
          limit={@limit}
        />
      </Group.render>

      <%= if !is_nil(@attempt) do %>
        <Group.render>
          <div class="rounded-2xl border border-Border-border-default bg-Surface-surface-primary p-4 shadow-[0px_8px_30px_0px_rgba(0,50,99,0.10)]">
            <div class="rounded-xl bg-Surface-surface-secondary px-4 py-4">
              <div class="mb-4 rounded-lg bg-Surface-surface-secondary-muted px-4 py-3">
                <div class="text-sm font-semibold text-Text-text-high">Selected Attempt</div>
                <div class="mt-1 text-sm text-Text-text-low">
                  The panels below belong to the currently selected manual grading row.
                </div>
              </div>

              <Tabs.render active={@active_tab} changed="change_tab" />

              <%= if @active_tab == :review do %>
                <SelectedSubmission.render submission={selected_submission(assigns)} class="mt-4" />
              <% else %>
                <div class="mt-4 rounded-xl bg-Surface-surface-primary px-4 py-4 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]">
                  <RenderedActivity.render rendered_activity={@preview_rendered} />
                </div>
              <% end %>

              <div class="mt-4 space-y-4">
                <%= if stale_attempt?(assigns) do %>
                  <div class="rounded-xl bg-Surface-surface-secondary-muted px-4 py-4">
                    <div class="text-sm font-semibold text-Text-text-high">Stale Attempt State</div>
                    <div class="mt-1 text-sm text-Text-text-low">
                      This activity is still queued for manual grading, but there are no remaining manual inputs to score.
                    </div>
                    <button
                      class="mt-3 inline-flex h-8 items-center justify-center rounded-md bg-Fill-Buttons-fill-primary px-4 text-sm font-semibold text-Text-text-white hover:bg-Fill-Buttons-fill-primary-hover"
                      phx-click="resolve_stale_attempt"
                    >
                      Resolve Attempt State
                    </button>
                  </div>
                <% end %>

                <div class="rounded-xl bg-Surface-surface-secondary-muted px-4 py-4">
                  <div class="mb-4 text-sm font-semibold text-Text-text-high">Input Scoring</div>
                  {render_parts(assigns)}
                </div>

                <div class="rounded-xl bg-Surface-surface-secondary-muted px-4 py-4">
                  <div :if={scoring_remains(assigns)} class="mb-4 text-sm text-Text-text-low">
                    Apply Score and Feedback stays disabled until every manually graded input has both a score and feedback.
                  </div>
                  <Apply.render disabled={scoring_remains(assigns)} apply="apply" />
                </div>
              </div>
            </div>
          </div>
        </Group.render>
      <% else %>
        <div style="margin-top: 200px;" class="d-flex justify-content-center">
          To get started with manual scoring of student activities, first select an activity attempt from above to review and score.
        </div>
      <% end %>

      <%= if pending_changes(assigns) do %>
        <div id="before_unload" phx-hook="BeforeUnloadListener" />
      <% end %>
    </div>
    """
  end

  def render_parts(assigns) do
    ~H"""
    <div class="space-y-3">
      <%= for pa <- @part_attempts do %>
        <div>
          <PartScoring.render
            part_attempt={pa}
            part_scoring={@score_feedbacks[pa.attempt_guid]}
            input_type_label={input_type_label(@attempt, pa, @activity_types_map)}
            feedback_changed="feedback_changed"
            score_changed="score_changed"
            feedback_required={pa.grading_approach == :manual and feedback_missing?(assigns, pa)}
            selected={@selected_part_attempt_guid == pa.attempt_guid}
            selected_changed="select_part"
          />
        </div>
      <% end %>
    </div>
    """
  end

  # Determines if any scoring or feedbacks remain to be entered for the part attempts
  # of the currently selected activity attempt
  defp scoring_remains(assigns) do
    not manual_scoring_ready?(assigns.part_attempts, assigns.score_feedbacks)
  end

  defp feedback_missing?(assigns, pa) do
    case Map.get(assigns.score_feedbacks || %{}, pa.attempt_guid) do
      %{feedback: feedback} -> is_nil(blank_to_nil(feedback))
      _ -> true
    end
  end

  defp input_type_label(attempt, part_attempt, activity_types_map) do
    SelectedSubmissionBuilder.input_type_label(attempt, part_attempt, activity_types_map)
  end

  def manual_scoring_ready?(part_attempts, score_feedbacks) do
    manual_part_attempts =
      Enum.filter(part_attempts || [], fn pa -> pa.grading_approach == :manual end)

    manual_part_attempts != [] and
      Enum.all?(manual_part_attempts, fn pa ->
        case Map.get(score_feedbacks || %{}, pa.attempt_guid) do
          %{score: score, feedback: feedback} ->
            not is_nil(score) and not is_nil(blank_to_nil(feedback))

          _ ->
            false
        end
      end)
  end

  # Determines if there are *any* pending changes
  defp pending_changes(assigns) do
    Map.values(assigns.score_feedbacks)
    |> Enum.any?(fn sf ->
      !is_nil(sf.score) or !is_nil(sf.feedback)
    end)
  end

  defp stale_attempt?(%{attempt: nil}), do: false
  defp stale_attempt?(%{part_attempts: nil}), do: false

  defp stale_attempt?(assigns) do
    assigns.attempt.lifecycle_state == :submitted and
      assigns.part_attempts != [] and
      !Enum.any?(assigns.part_attempts, fn pa ->
        pa.grading_approach == :manual and pa.lifecycle_state != :evaluated
      end)
  end

  defp determine_out_of(%Oli.Delivery.Attempts.Core.PartAttempt{part_id: part_id}, parts_map) do
    case Map.get(parts_map, part_id) do
      nil -> 1.0
      %Part{out_of: nil} -> 1.0
      %Part{out_of: out_of} -> out_of
    end
  end

  @spec patch_with(Phoenix.LiveView.Socket.t(), map) :: {:noreply, Phoenix.LiveView.Socket.t()}
  def patch_with(socket, changes) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           socket.assigns.section.slug,
           Map.merge(
             %{
               sort_by: socket.assigns.table_model.sort_by_spec.name,
               sort_order: socket.assigns.table_model.sort_order,
               offset: socket.assigns.offset,
               text_search: socket.assigns.options.text_search,
               user_id: socket.assigns.options.user_id,
               activity_id: socket.assigns.options.activity_id,
               page_id: socket.assigns.options.page_id,
               graded: socket.assigns.options.graded,
               selected: socket.assigns.table_model.selected
             },
             changes
           )
         ),
       replace: true
     )}
  end

  defp build_state_for_selection(%{selected: nil}, _),
    do: [
      attempt: nil,
      part_attempts: nil,
      preview_rendered: nil,
      selected_part_attempt_guid: nil,
      selected_part_id: nil,
      parts_map: %{}
    ]

  defp build_state_for_selection(%{selected: ""}, _),
    do: [
      attempt: nil,
      part_attempts: nil,
      preview_rendered: nil,
      selected_part_attempt_guid: nil,
      selected_part_id: nil,
      parts_map: %{}
    ]

  defp build_state_for_selection(table_model, assigns) do
    activity_attempt =
      Enum.find(table_model.rows, fn r -> r.id == String.to_integer(table_model.selected) end)

    # Only re-render the activities when it is the first selection or on an actual selection change
    if get_in(assigns, [:attempt, Access.key(:id)]) != activity_attempt.id do
      part_attempts = Core.get_latest_part_attempts(activity_attempt.attempt_guid)

      rendering_context =
        OliWeb.ManualGrading.Rendering.create_rendering_context(
          activity_attempt,
          part_attempts,
          assigns.activity_types_map,
          assigns.section
        )

      preview_rendered =
        OliWeb.ManualGrading.Rendering.render(rendering_context, :instructor_preview)

      {:ok, model} = Oli.Activities.Model.parse(activity_attempt.revision.content)
      parts_map = Enum.reduce(model.parts, %{}, fn p, m -> Map.put(m, p.id, p) end)
      selected_part_attempt = List.first(part_attempts)

      [
        attempt: activity_attempt,
        part_attempts: part_attempts,
        preview_rendered: preview_rendered,
        score_feedbacks:
          ensure_score_feedbacks_exist(assigns.score_feedbacks, part_attempts, parts_map),
        parts_map: parts_map,
        selected_part_attempt_guid: selected_part_attempt && selected_part_attempt.attempt_guid,
        selected_part_id: selected_part_attempt && selected_part_attempt.part_id
      ]
    else
      []
    end
  end

  def ensure_score_feedbacks_exist(score_feedbacks, part_attempts, parts_map) do
    Enum.reduce(part_attempts, score_feedbacks, fn pa, m ->
      if pa.grading_approach != :manual or Map.has_key?(m, pa.attempt_guid) do
        m
      else
        Map.put(m, pa.attempt_guid, %ScoreFeedback{
          score: nil,
          feedback: nil,
          out_of: determine_out_of(pa, parts_map)
        })
      end
    end)
  end

  # Determines if the change after parsing the URL params is strictly a selection change,
  # relative to the current assigns
  defp only_selection_changed(assigns, model_after, options_after, offset_after) do
    assigns.table_model.selected != model_after.selected and
      assigns.table_model.sort_by_spec == model_after.sort_by_spec and
      assigns.table_model.sort_order == model_after.sort_order and
      assigns.options.text_search == options_after.text_search and
      assigns.options.user_id == options_after.user_id and
      assigns.options.activity_id == options_after.activity_id and
      assigns.options.page_id == options_after.page_id and
      assigns.options.graded == options_after.graded and
      assigns.offset == offset_after
  end

  defp ensure_valid_score(score, attempt_guid, assigns) do
    out_of =
      case Enum.find(assigns.part_attempts, fn pa -> pa.attempt_guid == attempt_guid end) do
        nil -> 1.0
        pa -> determine_out_of(pa, assigns.parts_map)
      end

    min(score, out_of)
    |> max(0.0)
  end

  def handle_event("change_tab", %{"tab" => value}, socket) do
    {:noreply,
     assign(socket,
       active_tab: String.to_existing_atom(value)
     )}
  end

  def handle_event(
        "select_part",
        %{"attempt_guid" => attempt_guid, "part_id" => part_id} = params,
        socket
      ) do
    case Map.get(params, "key") do
      nil ->
        select_part(socket, attempt_guid, part_id)

      key when key in ["Enter", " ", "Space", "Spacebar"] ->
        select_part(socket, attempt_guid, part_id)

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("apply", _, socket) do
    if manual_scoring_ready?(socket.assigns.part_attempts, socket.assigns.score_feedbacks) do
      %{
        section: section,
        attempt: attempt,
        score_feedbacks: score_feedbacks
      } = socket.assigns

      case ManualGrading.apply_manual_scoring(section, attempt, score_feedbacks) do
        {:ok, finalized_part_attempt_guids} ->
          socket =
            socket
            |> assign(
              :score_feedbacks,
              purge_score_feedbacks(
                socket.assigns.score_feedbacks,
                finalized_part_attempt_guids
              )
            )
            |> put_flash(:info, "Student attempt scored.")
            |> refresh_after_attempt_removed()

          {:noreply, socket}

        _ ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "There was a problem encountered while scoring this attempt."
           )}
      end
    else
      {:noreply,
       put_flash(
         socket,
         :error,
         "Enter both a score and feedback for every manually graded input before applying."
       )}
    end
  end

  def handle_event("resolve_stale_attempt", _, socket) do
    case ManualGrading.resolve_stale_attempt(socket.assigns.section, socket.assigns.attempt) do
      {:ok, :ok} ->
        socket =
          socket
          |> put_flash(:info, "Stale attempt resolved.")
          |> refresh_after_attempt_removed()

        {:noreply, socket}

      _ ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "There was a problem resolving this stale attempt."
         )}
    end
  end

  def handle_event(
        "feedback_changed",
        %{"id" => "feedback_" <> attempt_guid, "value" => feedback},
        socket
      ) do
    sf = score_feedback_for(socket.assigns, attempt_guid)
    sf = %{sf | feedback: blank_to_nil(feedback)}

    score_feedbacks = Map.put(socket.assigns.score_feedbacks, attempt_guid, sf)

    {:noreply, assign(socket, score_feedbacks: score_feedbacks)}
  end

  def handle_event("score_changed", %{"id" => "score_" <> attempt_guid} = params, socket) do
    score =
      case Map.get(params, "score") do
        nil -> Map.get(params, "value")
        score -> score
      end

    case blank_to_nil(score) do
      nil ->
        sf = score_feedback_for(socket.assigns, attempt_guid)
        sf = %{sf | score: nil}
        score_feedbacks = Map.put(socket.assigns.score_feedbacks, attempt_guid, sf)

        {:noreply, assign(socket, score_feedbacks: score_feedbacks)}

      score ->
        case Float.parse(score) do
          :error ->
            {:noreply, socket}

          {score, _} ->
            score = ensure_valid_score(score, attempt_guid, socket.assigns)

            sf = score_feedback_for(socket.assigns, attempt_guid)
            sf = %{sf | score: score}
            score_feedbacks = Map.put(socket.assigns.score_feedbacks, attempt_guid, sf)

            {:noreply, assign(socket, score_feedbacks: score_feedbacks)}
        end
    end
  end

  def handle_event("prevent_default", _params, socket) do
    # This handler prevents default form submission behavior
    # The form should not be submitted, individual inputs are handled separately
    {:noreply, socket}
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &Filters.handle_delegated/4,
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end

  def handle_info({:purge_score_feedbacks, guids}, socket) do
    {:noreply,
     assign(
       socket,
       score_feedbacks: purge_score_feedbacks(socket.assigns.score_feedbacks, guids)
     )}
  end

  defp score_feedback_for(assigns, attempt_guid) do
    Map.get(assigns.score_feedbacks, attempt_guid) ||
      case Enum.find(assigns.part_attempts || [], fn pa -> pa.attempt_guid == attempt_guid end) do
        nil ->
          %ScoreFeedback{score: nil, feedback: nil, out_of: 1.0}

        pa ->
          %ScoreFeedback{
            score: nil,
            feedback: nil,
            out_of: determine_out_of(pa, assigns.parts_map || %{})
          }
      end
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp select_part(socket, attempt_guid, part_id) do
    {:noreply,
     assign(socket,
       selected_part_attempt_guid: attempt_guid,
       selected_part_id: part_id
     )}
  end

  defp selected_submission(%{attempt: nil}), do: nil
  defp selected_submission(%{part_attempts: nil}), do: nil
  defp selected_submission(%{selected_part_attempt_guid: nil}), do: nil

  defp selected_submission(assigns) do
    SelectedSubmissionBuilder.build(
      assigns.attempt,
      assigns.part_attempts,
      assigns.selected_part_attempt_guid,
      assigns.activity_types_map
    )
  end

  defp refresh_after_attempt_removed(socket) do
    attempts =
      ManualGrading.browse_submitted_attempts(
        socket.assigns.section,
        %Paging{offset: socket.assigns.offset, limit: socket.assigns.limit},
        %Sorting{
          direction: socket.assigns.table_model.sort_order,
          field: socket.assigns.table_model.sort_by_spec.name
        },
        socket.assigns.options
      )

    selected =
      next_selected_after_removal(
        socket.assigns.table_model.rows,
        socket.assigns.table_model.selected,
        attempts
      )

    table_model =
      socket.assigns.table_model
      |> Map.put(:rows, attempts)
      |> Map.put(:selected, selected)

    socket
    |> assign(
      table_model: table_model,
      total_count: determine_total(attempts)
    )
    |> assign(build_state_for_selection(table_model, socket.assigns))
  end

  defp purge_score_feedbacks(score_feedbacks, guids) do
    Enum.reduce(guids, score_feedbacks, fn guid, sfs ->
      Map.delete(sfs, guid)
    end)
  end

  defp next_selected_after_removal(_current_rows, _current_selected, []), do: nil

  defp next_selected_after_removal(current_rows, current_selected, refreshed_rows) do
    index =
      Enum.find_index(current_rows, fn row ->
        Integer.to_string(row.id) == current_selected
      end)

    cond do
      is_nil(index) ->
        refreshed_rows |> hd() |> Map.fetch!(:id) |> Integer.to_string()

      index >= length(refreshed_rows) ->
        refreshed_rows |> List.last() |> Map.fetch!(:id) |> Integer.to_string()

      true ->
        refreshed_rows |> Enum.at(index) |> Map.fetch!(:id) |> Integer.to_string()
    end
  end
end
