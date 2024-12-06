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

  def mount(%{"section_slug" => section_slug}, session, socket) do
    case Mount.for(section_slug, session) do
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
          <Tabs.render active={@active_tab} changed="change_tab" />
          <%= if @active_tab == :review do %>
            <RenderedActivity.render rendered_activity={@review_rendered} />
          <% else %>
            <RenderedActivity.render rendered_activity={@preview_rendered} />
          <% end %>
        </Group.render>
        <Group.render>
          <%= render_parts(assigns) %>
          <Apply.render disabled={scoring_remains(assigns)} apply="apply" />
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
    <%= for pa <- @part_attempts do %>
      <PartScoring.render
        part_attempt={pa}
        part_scoring={@score_feedbacks[pa.attempt_guid]}
        feedback_changed="feedback_changed"
        score_changed="score_changed"
      />
      <hr />
    <% end %>
    """
  end

  # Determines if any scoring or feedbacks remain to be entered for the part attempts
  # of the currently selected activity attempt
  defp scoring_remains(assigns) do
    attempt_guids =
      Enum.filter(assigns.part_attempts, fn pa -> pa.grading_approach == :manual end)
      |> Enum.map(fn pa -> pa.attempt_guid end)
      |> MapSet.new()

    Map.keys(assigns.score_feedbacks)
    |> Enum.filter(fn guid -> MapSet.member?(attempt_guids, guid) end)
    |> Enum.any?(fn guid ->
      sf = Map.get(assigns.score_feedbacks, guid)
      is_nil(sf.score) or is_nil(sf.feedback)
    end)
  end

  # Determines if there are *any* pending changes
  defp pending_changes(assigns) do
    Map.values(assigns.score_feedbacks)
    |> Enum.any?(fn sf ->
      !is_nil(sf.score) or !is_nil(sf.feedback)
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
    do: [attempt: nil, part_attempts: nil, review_rendered: nil, preview_rendered: nil]

  defp build_state_for_selection(%{selected: ""}, _),
    do: [attempt: nil, part_attempts: nil, review_rendered: nil, preview_rendered: nil]

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

      review_rendered = OliWeb.ManualGrading.Rendering.render(rendering_context, :review)

      preview_rendered =
        OliWeb.ManualGrading.Rendering.render(rendering_context, :instructor_preview)

      {:ok, model} = Oli.Activities.Model.parse(activity_attempt.revision.content)
      parts_map = Enum.reduce(model.parts, %{}, fn p, m -> Map.put(m, p.id, p) end)

      [
        attempt: activity_attempt,
        part_attempts: part_attempts,
        review_rendered: review_rendered,
        preview_rendered: preview_rendered,
        score_feedbacks:
          ensure_score_feedbacks_exist(assigns.score_feedbacks, part_attempts, parts_map),
        parts_map: parts_map
      ]
    else
      []
    end
  end

  def ensure_score_feedbacks_exist(score_feedbacks, part_attempts, parts_map) do
    Enum.reduce(part_attempts, score_feedbacks, fn pa, m ->
      if Map.has_key?(m, pa.attempt_guid) do
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

  def handle_event("apply", _, socket) do
    %{
      section: section,
      attempt: attempt,
      score_feedbacks: score_feedbacks
    } = socket.assigns

    case ManualGrading.apply_manual_scoring(section, attempt, score_feedbacks) do
      {:ok, finalized_part_attempts} ->
        pid = self()

        send(
          pid,
          {:purge_score_feedbacks,
           Enum.map(finalized_part_attempts, fn pa -> pa.attempt_guid end)}
        )

        put_flash(socket, :info, "Student attempt scored.")
        |> pick_next()

      _ ->
        {:noreply,
         put_flash(socket, :error, "There was a problem encountered while scoring this attempt.")}
    end
  end

  def handle_event(
        "feedback_changed",
        %{"id" => "feedback_" <> attempt_guid, "value" => feedback},
        socket
      ) do
    sf = Map.get(socket.assigns.score_feedbacks, attempt_guid)
    sf = %{sf | feedback: feedback}

    score_feedbacks = Map.put(socket.assigns.score_feedbacks, attempt_guid, sf)

    {:noreply, assign(socket, score_feedbacks: score_feedbacks)}
  end

  def handle_event("score_changed", %{"id" => "score_" <> attempt_guid} = params, socket) do
    score =
      case Map.get(params, "score") do
        nil -> Map.get(params, "value")
        score -> score
      end

    case Float.parse(score) do
      :error ->
        {:noreply, socket}

      {score, _} ->
        score = ensure_valid_score(score, attempt_guid, socket.assigns)

        sf = Map.get(socket.assigns.score_feedbacks, attempt_guid)
        sf = %{sf | score: score}
        score_feedbacks = Map.put(socket.assigns.score_feedbacks, attempt_guid, sf)

        {:noreply, assign(socket, score_feedbacks: score_feedbacks)}
    end
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
    score_feedbacks =
      Enum.reduce(guids, socket.assigns.score_feedbacks, fn guid, sfs ->
        Map.delete(sfs, guid)
      end)

    {:noreply, assign(socket, score_feedbacks: score_feedbacks)}
  end

  # After a score is applied for an attempt, we need to determine what is the next
  # attempt that should be selected.  We want this to emulate a 'queue' of sorts, so
  # that the next item after the selected item becomes the next selected item. We
  # must encode this index based selection in some way that is distinguishable from a
  # normal Id reference, so we do that be encoding it as a negative number, with a special
  # case of "none" for when there should not be a selection (i.e. the user has evaluated)
  # the last attempt.
  defp pick_next(socket) do
    index =
      Enum.find_index(socket.assigns.table_model.rows, fn r ->
        Integer.to_string(r.id) == socket.assigns.table_model.selected
      end)

    selected =
      cond do
        is_nil(index) -> "none"
        socket.assigns.total_count == 1 -> "none"
        socket.assigns.total_count == index + 1 -> (index - 1) * -1
        true -> index * -1
      end

    patch_with(socket, %{selected: selected})
  end
end
