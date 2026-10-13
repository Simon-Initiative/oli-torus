defmodule OliWeb.ManualGrading.ScoringLive do
  @moduledoc """
  Dedicated scoring page for one submission awaiting manual scoring. The queue it
  walks with Previous/Next is the table's current filtered and sorted result, carried in the
  URL params; the draft score/feedback lives in the form on the client.
  """
  use OliWeb, :live_view

  alias Oli.Delivery.Attempts.ManualGrading
  alias OliWeb.Breadcrumb.BreadcrumbLive
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Common.Utils
  alias OliWeb.Icons
  alias OliWeb.ManualGrading.AttemptState
  alias OliWeb.ManualGrading.BrowseParams
  alias OliWeb.ManualGrading.RenderedActivity
  alias OliWeb.ManualGrading.Rendering
  alias OliWeb.ManualGrading.ScoreFeedback
  alias OliWeb.ManualGrading.SelectedSubmission
  alias OliWeb.ManualGrading.SelectedSubmissionBuilder
  alias OliWeb.ManualGrading.Tabs
  alias OliWeb.ManualGrading.UnsavedScoresModal
  alias OliWeb.Sections.Mount

  @not_awaiting_notice "This submission is no longer awaiting scoring."

  def mount(%{"section_slug" => section_slug}, _session, socket) do
    case Mount.for(section_slug, socket) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, _, section} ->
        activities = Oli.Activities.list_activity_registrations()
        part_components = Oli.PartComponents.get_part_component_scripts(:delivery_script)

        {:ok,
         assign(socket,
           section: section,
           title: "Manual Scoring",
           # the layout's breadcrumb trail reads its crumbs only when it mounts; this page renders
           # its own so the student's name follows Previous/Next
           breadcrumbs: [],
           role_breadcrumbs: OliWeb.Sections.OverviewView.set_breadcrumbs(type, section),
           activity_types_map: Map.new(activities, &{&1.id, &1}),
           additional_scripts:
             Enum.map(activities, & &1.authoring_script) |> Enum.concat(part_components),
           table_params: %{},
           attempt: nil,
           part_attempts: [],
           parts_map: %{},
           selected_guid: nil,
           preview_rendered: nil,
           position: nil,
           active_tab: :review,
           form_params: %{},
           readonly: false,
           not_awaiting: false,
           show_unsaved_modal: false
         )}
    end
  end

  def handle_params(params, _uri, socket) do
    table_params = BrowseParams.table_params(params)

    with {:ok, id} <- BrowseParams.attempt_id(params["attempt_id"]),
         %{} = row <- ManualGrading.fetch_submitted_attempt(socket.assigns.section, id) do
      {:noreply,
       socket
       |> load_submission(row, params, table_params)
       |> push_event("scoring:focus_heading", %{})}
    else
      _ ->
        {:noreply,
         socket
         |> put_flash(:info, @not_awaiting_notice)
         |> redirect(to: table_path(socket.assigns.section, table_params))}
    end
  end

  defp load_submission(socket, row, params, table_params) do
    %{section: section, activity_types_map: activity_types_map} = socket.assigns
    sorting = BrowseParams.sorting(params)
    options = BrowseParams.browse_options(params)
    anchor = %{id: row.id, key: ManualGrading.sort_key_value(row, sorting.field)}
    position = ManualGrading.submission_position(section, sorting, options, anchor)
    part_attempts = AttemptState.part_attempts(row)

    preview_rendered =
      row
      |> Rendering.create_rendering_context(part_attempts, activity_types_map, section)
      |> Rendering.render(:instructor_preview)

    selected =
      Enum.find(part_attempts, List.first(part_attempts), &(&1.grading_approach == :manual))

    assign(socket,
      attempt: row,
      sorting: sorting,
      options: options,
      # No anchor on a deep link outside the filtered queue — nothing to walk from, now or later
      anchor: if(position.anchor_eligible?, do: anchor, else: nil),
      position: without_navigation_when_excluded(position),
      table_params: table_params,
      part_attempts: part_attempts,
      parts_map: AttemptState.parts_map(row, part_attempts),
      preview_rendered: preview_rendered,
      selected_guid: selected && selected.attempt_guid,
      form_params: %{},
      readonly: false,
      not_awaiting: false,
      show_unsaved_modal: false
    )
  end

  # A deep link to a pending submission the URL filters exclude has no anchor to walk from.
  defp without_navigation_when_excluded(%{anchor_eligible?: false} = position),
    do: %{position | previous_id: nil, next_id: nil}

  defp without_navigation_when_excluded(position), do: position

  defp table_path(section, table_params) when table_params == %{},
    do: ~p"/sections/#{section.slug}/scoring"

  defp table_path(section, table_params),
    do: ~p"/sections/#{section.slug}/scoring?#{table_params}"

  defp scoring_path(section, id, table_params) when table_params == %{},
    do: ~p"/sections/#{section.slug}/scoring/#{id}"

  defp scoring_path(section, id, table_params),
    do: ~p"/sections/#{section.slug}/scoring/#{id}?#{table_params}"

  defp crumbs(assigns) do
    assigns.role_breadcrumbs ++
      [
        Breadcrumb.new(%{
          full_title: "Manual Scoring",
          link: table_path(assigns.section, assigns.table_params)
        }),
        Breadcrumb.new(%{
          full_title: Utils.name(assigns.attempt.user),
          short_title: Utils.name(assigns.attempt.user),
          link: nil
        })
      ]
  end

  def render(assigns) do
    assigns = assign(assigns, :crumbs, crumbs(assigns))

    ~H"""
    <%!-- scroll-mt: whatever gets focus or is scrolled to clears the sticky dashboard header (57px) --%>
    <div class="container mx-auto my-4 space-y-4 [&_*]:scroll-mt-16" id="scoring-page">
      <%= for script <- @additional_scripts do %>
        <script type="text/javascript" src={Routes.static_path(OliWeb.Endpoint, "/js/" <> script)}>
        </script>
      <% end %>

      <nav aria-label="breadcrumb" class="breadcrumb-bar mt-3 mb-1">
        <ol class="breadcrumb custom-breadcrumb">
          <.live_component
            :for={{crumb, index} <- Enum.with_index(@crumbs)}
            module={BreadcrumbLive}
            id={"scoring-breadcrumb-#{index}"}
            breadcrumb={crumb}
            is_last={index == length(@crumbs) - 1}
            show_short={length(@crumbs) > 3}
          />
        </ol>
      </nav>

      <div
        id="scoring-guard"
        phx-hook="NavigationGuard"
        data-saved="true"
        data-dirty-form="#scoring-form"
      >
      </div>

      <div class="pb-1 pt-3">
        <.link
          id="back-to-table"
          href={table_path(@section, @table_params)}
          data-scoring-nav
          class={[
            "flex w-fit items-center gap-2 py-4 text-lg font-semibold leading-6 text-Text-text-high",
            saving_class()
          ]}
        >
          <span class="flex h-5 w-5 shrink-0 items-center justify-center">
            <Icons.back_arrow class="stroke-Icon-icon-active" />
          </span>
          Back to all manually scored activities
        </.link>
      </div>

      <div class="grid grid-cols-1 gap-4 xl:grid-cols-[minmax(0,1fr)_305px] xl:items-start xl:gap-3">
        <div>
          <div class="rounded-2xl border border-Border-border-default bg-Surface-surface-primary p-4 shadow-[0px_8px_30px_0px_rgba(0,50,99,0.10)] xl:rounded-b-none">
            <div class="border-Border-border-default py-1.5 xl:border-b">
              <div class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
                <h1
                  id="scoring-heading"
                  tabindex="-1"
                  phx-hook="ScoringHeading"
                  class="text-2xl font-semibold text-Text-text-high focus:outline-none focus-visible:ring-2 focus-visible:ring-Border-border-bold"
                >
                  {Utils.name(@attempt.user)}
                </h1>
                <nav aria-label="Submission navigation" class="flex items-center gap-2.5">
                  {nav_link(assigns, :previous)}
                  <span
                    :if={@position.anchor_eligible?}
                    id="submission-position"
                    class="text-base leading-8 text-Text-text-low"
                  >
                    {@position.position} of {@position.total}
                  </span>
                  {nav_link(assigns, :next)}
                </nav>
              </div>
              <div id="submission-meta" class="text-base leading-8 text-Text-text-low">
                {@attempt.activity_title}<span class="ml-2.5 mr-3.5 text-Icon-icon-default">·</span>Submitted {Utils.render_date(
                  @attempt,
                  :date_submitted,
                  @ctx
                )}
              </div>
            </div>

            <%!-- below xl the selected input shows inside the scoring panel instead --%>
            <div class="mt-4 hidden xl:block">
              <Tabs.render id="scoring-tabs" active={@active_tab} changed="change_tab" />
            </div>
          </div>

          <div class="hidden rounded-b-2xl border border-Border-border-default bg-Background-bg-primary p-4 shadow-[0px_8px_30px_0px_rgba(0,50,99,0.10)] xl:block">
            <Tabs.panel id="scoring-tabs" active={@active_tab} key={:review}>
              <SelectedSubmission.render submission={
                SelectedSubmissionBuilder.build(
                  @attempt,
                  @part_attempts,
                  @selected_guid,
                  @activity_types_map
                )
              } />
            </Tabs.panel>
            <Tabs.panel
              id="scoring-tabs"
              active={@active_tab}
              key={:preview}
              class="overflow-x-auto [&>.rendered-activity]:mt-0"
            >
              <RenderedActivity.render id="scoring-preview" rendered_activity={@preview_rendered} />
            </Tabs.panel>
          </div>
        </div>

        <div
          id="scoring-panel"
          class="rounded-2xl border border-Border-border-default bg-Surface-surface-primary shadow-[0px_8px_30px_0px_rgba(0,50,99,0.10)] xl:sticky xl:top-20 xl:max-h-[calc(100vh-6rem)] xl:overflow-y-auto"
        >
          <div class="px-4 pt-4">
            <div class="border-b border-Border-border-default pb-[13px] pt-3">
              <h2 class="text-xl font-bold leading-5 text-Text-text-high">Manual Grading</h2>

              <div class="mt-2 flex flex-col gap-2">
                <div
                  :for={
                    {pa, label} <-
                      SelectedSubmissionBuilder.input_labels(
                        @attempt,
                        @part_attempts,
                        @activity_types_map
                      )
                  }
                  class="flex flex-wrap items-center gap-y-2"
                >
                  <span
                    id={"input_label_" <> pa.attempt_guid}
                    class="inline-flex items-center rounded-full border border-Border-border-default bg-Surface-surface-primary px-2.5 pb-[3.565px] pt-[3.445px] text-xs leading-5 font-semibold text-Text-text-high"
                  >
                    {label}
                  </span>
                  <span id={"input_status_" <> pa.attempt_guid} aria-live="polite" class="inline-flex">
                    <span
                      :if={scored?(pa, @form_params)}
                      class={[
                        "ml-2 inline-flex items-center rounded-full border px-2.5 pb-[3.565px] pt-[3.445px] text-xs leading-5 font-semibold",
                        scored_badge_classes(pa.lifecycle_state)
                      ]}
                    >
                      Scored
                    </span>
                  </span>
                  <button
                    type="button"
                    id={"select_" <> pa.attempt_guid}
                    phx-click="select_part"
                    phx-value-guid={pa.attempt_guid}
                    aria-pressed={to_string(pa.attempt_guid == @selected_guid)}
                    aria-labelledby={"select_text_#{pa.attempt_guid} input_label_#{pa.attempt_guid}"}
                    class={[
                      "ml-2 inline-flex items-center rounded-full border px-2.5 pb-[3.565px] pt-[3.445px] text-xs leading-5 font-semibold focus:outline-none focus-visible:ring-2 focus-visible:ring-Border-border-bold focus-visible:ring-offset-2",
                      select_button_classes(pa.attempt_guid == @selected_guid)
                    ]}
                  >
                    <span id={"select_text_" <> pa.attempt_guid}>
                      {select_button_text(pa.attempt_guid == @selected_guid)}
                    </span>
                  </button>
                </div>
              </div>
            </div>

            <%!-- one id per submission: Previous/Next remount the hook, so focus goes to the heading --%>
            <div
              id={"scoring-context-#{@attempt.id}"}
              phx-hook="ManualGradingMobileFocus"
              data-selected-part-attempt-guid={@selected_guid}
              tabindex="-1"
              class="mt-4 rounded-xl bg-Surface-surface-secondary-muted px-4 py-4 xl:hidden"
            >
              <div class="mb-4 text-sm font-semibold text-Text-text-high">
                Selected Input Context
              </div>
              <Tabs.render id="scoring-context-tabs" active={@active_tab} changed="change_tab" />
              <Tabs.panel id="scoring-context-tabs" active={@active_tab} key={:review}>
                <SelectedSubmission.render
                  submission={
                    SelectedSubmissionBuilder.build(
                      @attempt,
                      @part_attempts,
                      @selected_guid,
                      @activity_types_map
                    )
                  }
                  class="mt-4"
                />
              </Tabs.panel>
              <Tabs.panel
                id="scoring-context-tabs"
                active={@active_tab}
                key={:preview}
                class="mt-4 overflow-x-auto rounded-xl bg-Surface-surface-primary px-4 py-4"
              >
                <RenderedActivity.render
                  id="scoring-preview-narrow"
                  rendered_activity={@preview_rendered}
                />
              </Tabs.panel>
            </div>
          </div>

          <.form
            for={%{}}
            id="scoring-form"
            phx-change="draft_changed"
            phx-submit="apply"
            phx-auto-recover="recover_draft"
            novalidate
          >
            <div class="space-y-4 px-4 pb-4 pt-3">
              <div
                :for={pa <- @part_attempts}
                id={"part_" <> pa.attempt_guid}
                hidden={pa.attempt_guid != @selected_guid}
                class="space-y-3"
              >
                <div
                  :if={not editable?(pa)}
                  class="rounded-lg bg-Surface-surface-secondary-muted px-3 py-3 text-sm text-Text-text-low"
                >
                  <div class="font-semibold text-Text-text-high">
                    {if pa.grading_approach == :manual, do: "Scored", else: "Automatically Graded"}
                  </div>
                  <div>
                    {if pa.grading_approach == :manual,
                      do: "This input was already scored and is read only here.",
                      else: "This input was scored by the system and is read only here."} Score: {pa.score ||
                      "Pending"} / {pa.out_of || AttemptState.out_of(pa, @parts_map)}
                  </div>
                  <%!-- one line: under pre-wrap, line breaks around the text would show --%>
                  <div
                    class="mt-2 whitespace-pre-wrap break-words text-Text-text-high"
                    phx-no-format
                  >{readonly_feedback(pa)}</div>
                </div>
                <div :if={editable?(pa)} class="space-y-3">
                  <div class="max-w-[14rem]">
                    <label
                      for={"score_" <> pa.attempt_guid}
                      class="mb-2 block text-sm font-semibold text-Text-text-high"
                    >
                      Score
                    </label>
                    <input
                      id={"score_" <> pa.attempt_guid}
                      name={"score_" <> pa.attempt_guid}
                      type="number"
                      step="any"
                      min="0"
                      max={AttemptState.out_of(pa, @parts_map)}
                      value={Map.get(@form_params, "score_" <> pa.attempt_guid, "")}
                      data-initial=""
                      data-scoring-edit
                      phx-debounce="300"
                      phx-hook="ScoringScoreInput"
                      readonly={@readonly}
                      class="block w-full rounded-lg border border-Border-border-default px-3 py-2 text-sm text-Text-text-high"
                    />
                  </div>
                  <div class="max-w-[14rem]">
                    <label
                      for={"out_of_" <> pa.attempt_guid}
                      class="mb-2 block text-sm font-semibold text-Text-text-high"
                    >
                      Out Of
                    </label>
                    <input
                      id={"out_of_" <> pa.attempt_guid}
                      type="text"
                      readonly
                      aria-readonly="true"
                      value={AttemptState.out_of(pa, @parts_map)}
                      class="block w-full rounded-lg border border-Border-border-subtle bg-Surface-surface-secondary-muted px-3 py-2 text-sm text-Text-text-high"
                    />
                  </div>
                  <div
                    class="grid max-w-[14rem] grid-cols-3 gap-2"
                    role="group"
                    aria-label="Scoring shortcut group"
                  >
                    <button
                      :for={{label, value} <- chips(pa, @parts_map)}
                      type="button"
                      id={"chip_#{label}_" <> pa.attempt_guid}
                      phx-hook="ScoringChip"
                      data-target={"score_" <> pa.attempt_guid}
                      data-value={value}
                      disabled={@readonly}
                      class="h-8 rounded-md border border-Specially-Tokens-Text-text-button-secondary bg-Specially-Tokens-Fill-fill-input text-sm font-semibold leading-4 text-Text-text-button shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)]"
                    >
                      {label}%
                    </button>
                  </div>
                  <div class="max-w-[263px]">
                    <label
                      for={"feedback_" <> pa.attempt_guid}
                      class="mb-2 block text-sm font-semibold text-Text-text-high"
                    >
                      Feedback
                      <span class="ml-2 text-xs uppercase leading-5 tracking-wide text-Text-text-high">
                        (Required)
                      </span>
                    </label>
                    <textarea
                      id={"feedback_" <> pa.attempt_guid}
                      name={"feedback_" <> pa.attempt_guid}
                      data-initial=""
                      data-scoring-edit
                      phx-debounce="300"
                      readonly={@readonly}
                      maxlength="2000"
                      rows="5"
                      placeholder="Enter feedback for the student..."
                      aria-required="true"
                      aria-invalid={to_string(feedback_invalid?(pa, @form_params))}
                      aria-describedby={describedby(pa, @form_params)}
                      class="block w-full rounded-lg border border-Border-border-default bg-Surface-surface-primary px-3 py-3 text-sm text-Text-text-high min-h-[160px] shadow-[0px_0px_0px_1px_rgba(59,118,211,0.5)] placeholder:text-Text-text-high"
                    >{Map.get(@form_params, "feedback_" <> pa.attempt_guid, "")}</textarea>
                    <p
                      id={"feedback_help_" <> pa.attempt_guid}
                      class="mt-2 text-xs text-Text-text-high"
                    >
                      Feedback is required before you can apply grading for this activity.
                    </p>
                    <div aria-live="polite">
                      <p
                        :if={feedback_missing?(pa, @form_params)}
                        id={"feedback_error_" <> pa.attempt_guid}
                        class="mt-2 text-xs text-Text-text-high"
                      >
                        Add feedback for this input to enable Apply Score and Feedback.
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              <div
                :if={@not_awaiting}
                id="submission-status"
                role="status"
                class="text-sm text-Text-text-low"
              >
                {not_awaiting_notice()}
              </div>
              <div :if={not @readonly and editable_parts(@part_attempts) == []} class="space-y-2">
                <p class="text-sm text-Text-text-low">
                  This activity is still queued for manual scoring, but there are no remaining manual inputs to score.
                </p>
                <button
                  type="button"
                  phx-click="resolve_stale_attempt"
                  class="inline-flex h-9 items-center justify-center rounded-md bg-Fill-Buttons-fill-primary px-4 text-sm font-semibold text-Text-text-white"
                >
                  Resolve Attempt State
                </button>
              </div>
            </div>
            <div
              :if={not @readonly and editable_parts(@part_attempts) != []}
              class="space-y-4 border-t border-Border-border-default px-[15px] pb-[15px] pt-4"
            >
              <p :if={not ready?(@part_attempts, @form_params)} class="text-sm text-Text-text-high">
                Apply Score and Feedback stays disabled until every manually graded input has both a score and feedback.
              </p>
              <div class="flex justify-center">
                <button
                  id="apply-button"
                  type="submit"
                  disabled={not ready?(@part_attempts, @form_params)}
                  class="inline-flex h-10 items-center justify-center rounded-md bg-Fill-Buttons-fill-primary px-5 text-sm font-semibold text-Text-text-white disabled:bg-Fill-Buttons-fill-primary-muted disabled:text-Specially-Tokens-Text-text-button-muted disabled:opacity-50"
                >
                  Apply Score and Feedback
                </button>
              </div>
            </div>
          </.form>
        </div>
      </div>

      <UnsavedScoresModal.render :if={@show_unsaved_modal} />
    </div>
    """
  end

  defp nav_link(assigns, direction) do
    {id, label, target_id, chevron, width, label_width} =
      case direction do
        :previous ->
          {"previous-link", "Previous", assigns.position.previous_id,
           "M12.25 5.5L7.75 10L12.25 14.5", "w-[115px]", "w-[63px]"}

        :next ->
          {"next-link", "Next", assigns.position.next_id, "M7.75 5.5L12.25 10L7.75 14.5",
           "w-[101px]", "w-[45px]"}
      end

    assigns =
      assign(assigns,
        id: id,
        label: label,
        target_id: target_id,
        chevron: chevron,
        width: width,
        label_width: label_width,
        direction: direction
      )

    ~H"""
    <%= if @target_id do %>
      <.link
        id={@id}
        patch={scoring_path(@section, @target_id, @table_params)}
        replace
        data-scoring-nav
        class={[
          nav_link_classes(),
          @width,
          "border-Border-border-bold text-Text-text-high",
          saving_class()
        ]}
      >
        {nav_link_content(assigns)}
      </.link>
    <% else %>
      <a
        id={@id}
        role="link"
        aria-disabled="true"
        class={[nav_link_classes(), @width, "border-Border-border-muted text-Text-text-disabled"]}
      >
        {nav_link_content(assigns)}
      </a>
    <% end %>
    """
  end

  defp nav_link_classes,
    do:
      "flex h-[46px] items-center justify-center gap-1 rounded-lg border px-3 text-sm font-semibold leading-4 shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)]"

  defp nav_link_content(assigns) do
    ~H"""
    <Icons.chevron_down
      :if={@direction == :previous}
      variant="stroke"
      width="20"
      height="20"
      view_box="0 0 20 20"
      path={@chevron}
      class="shrink-0"
    />
    <span class={["px-1", @label_width]}>{@label}</span>
    <Icons.chevron_down
      :if={@direction == :next}
      variant="stroke"
      width="20"
      height="20"
      view_box="0 0 20 20"
      path={@chevron}
      class="shrink-0"
    />
    """
  end

  # Previous / Next / Back look disabled while Apply is in flight (LiveView marks the submitting
  # form with `phx-submit-loading`); `NavigationGuard` ignores their clicks meanwhile.
  defp saving_class,
    do:
      "[#scoring-page:has(#scoring-form.phx-submit-loading)_&]:cursor-not-allowed [#scoring-page:has(#scoring-form.phx-submit-loading)_&]:opacity-50"

  defp select_button_classes(true),
    do:
      "border-Fill-Buttons-fill-primary bg-Fill-Buttons-fill-primary text-Text-text-white shadow-[0px_1px_4px_0px_rgba(0,50,99,0.18)]"

  defp select_button_classes(false),
    do:
      "border-Border-border-default bg-Surface-surface-primary text-Text-text-low hover:border-Border-border-bold hover:text-Text-text-high"

  defp select_button_text(true), do: "Selected Input"
  defp select_button_text(false), do: "Select Input"

  defp chips(pa, parts_map) do
    out_of = AttemptState.out_of(pa, parts_map)
    [{0, 0}, {50, out_of / 2}, {100, out_of}]
  end

  defp not_awaiting_notice, do: @not_awaiting_notice

  defp manual_parts(part_attempts),
    do: Enum.filter(part_attempts, &(&1.grading_approach == :manual))

  # Only manual parts still awaiting a score are edited here; evaluated ones are read-only.
  defp editable?(pa), do: pa.grading_approach == :manual and pa.lifecycle_state == :submitted
  defp editable_parts(part_attempts), do: Enum.filter(part_attempts, &editable?/1)

  defp ready?(part_attempts, params) do
    manual = editable_parts(part_attempts)
    manual != [] and Enum.all?(manual, &part_ready?(&1, params))
  end

  defp part_ready?(pa, params),
    do:
      present_score?(params["score_" <> pa.attempt_guid]) and
        present?(params["feedback_" <> pa.attempt_guid])

  defp scored?(%{grading_approach: :manual, lifecycle_state: :evaluated}, _params), do: true
  defp scored?(pa, params), do: editable?(pa) and part_ready?(pa, params)

  defp scored_badge_classes(:evaluated),
    do:
      "border-Fill-Accent-fill-accent-teal-bold bg-Fill-Accent-fill-accent-teal text-Text-text-accent-teal"

  defp scored_badge_classes(_draft),
    do:
      "border-Fill-Accent-fill-accent-blue-bold bg-Fill-Accent-fill-accent-blue text-Text-text-accent-blue"

  defp present?(v) when is_binary(v), do: String.trim(v) != ""
  defp present?(_), do: false

  defp present_score?(v), do: parse_score(v) != nil

  defp parse_score(v) when is_binary(v), do: v |> String.trim() |> AttemptState.parse_number()
  defp parse_score(_), do: nil

  defp feedback_missing?(pa, params), do: not present?(params["feedback_" <> pa.attempt_guid])

  defp feedback_invalid?(pa, params),
    do: present?(params["score_" <> pa.attempt_guid]) and feedback_missing?(pa, params)

  defp describedby(pa, params) do
    (["feedback_help_" <> pa.attempt_guid] ++
       if(feedback_missing?(pa, params), do: ["feedback_error_" <> pa.attempt_guid], else: []))
    |> Enum.join(" ")
  end

  defp allowed_params(params, part_attempts) do
    keys =
      part_attempts
      |> editable_parts()
      |> Enum.flat_map(&["score_" <> &1.attempt_guid, "feedback_" <> &1.attempt_guid])

    params
    |> Map.take(keys)
    |> Map.filter(fn {_k, v} -> is_binary(v) end)
  end

  def handle_event("change_tab", %{"tab" => tab}, socket) when tab in ["review", "preview"] do
    {:noreply, socket |> assign(active_tab: String.to_existing_atom(tab)) |> revalidate_pending()}
  end

  def handle_event("draft_changed", _params, %{assigns: %{readonly: true}} = socket),
    do: {:noreply, socket}

  # Every change carries the whole form, but only the input it names is current: a debounced
  # change can arrive after a reconnect restored the draft, with the new page's blank inputs.
  def handle_event("draft_changed", params, socket) do
    changed =
      params
      |> allowed_params(socket.assigns.part_attempts)
      |> Map.take(List.wrap(params["_target"]))

    {:noreply,
     socket
     |> assign(form_params: Map.merge(socket.assigns.form_params, changed))
     |> revalidate_pending()}
  end

  def handle_event("recover_draft", _params, %{assigns: %{readonly: true}} = socket),
    do: {:noreply, socket}

  def handle_event("recover_draft", params, socket) do
    {:noreply,
     socket
     |> assign(form_params: allowed_params(params, socket.assigns.part_attempts))
     |> revalidate_pending()}
  end

  def handle_event("select_part", %{"guid" => guid}, socket) do
    case Enum.any?(socket.assigns.part_attempts, &(&1.attempt_guid == guid)) do
      true -> {:noreply, socket |> assign(selected_guid: guid) |> revalidate_pending()}
      false -> {:noreply, socket}
    end
  end

  def handle_event("resolve_stale_attempt", _params, %{assigns: %{readonly: true}} = socket),
    do: {:noreply, socket}

  def handle_event("resolve_stale_attempt", _params, socket) do
    %{section: section, attempt: attempt} = socket.assigns
    part_attempts = AttemptState.part_attempts(attempt)

    with %{} <- ManualGrading.fetch_submitted_attempt(section, attempt.id),
         true <- Enum.all?(manual_parts(part_attempts), &(&1.lifecycle_state == :evaluated)),
         {:ok, :ok} <- ManualGrading.resolve_stale_attempt(section, attempt) do
      {:noreply,
       socket
       |> put_flash(:info, "Stale attempt resolved.")
       |> assign(part_attempts: part_attempts, readonly: true)
       |> recompute_position()}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "There was a problem resolving this stale attempt.")}
    end
  end

  def handle_event("apply", _params, %{assigns: %{readonly: true}} = socket),
    do: {:noreply, socket}

  def handle_event("apply", params, socket) do
    %{part_attempts: part_attempts, parts_map: parts_map, section: section, attempt: attempt} =
      socket.assigns

    params = allowed_params(params, part_attempts)

    cond do
      not ready?(part_attempts, params) ->
        {:noreply, assign(socket, form_params: params)}

      is_nil(ManualGrading.fetch_submitted_attempt(section, attempt.id)) ->
        # someone else scored it since it was opened: keep the draft visible, read-only
        {:noreply,
         socket
         |> put_flash(:error, "This submission was already scored by someone else.")
         |> assign(form_params: params, readonly: true)
         |> recompute_position()}

      true ->
        score_feedbacks =
          part_attempts
          |> editable_parts()
          |> Map.new(fn pa ->
            {pa.attempt_guid,
             %ScoreFeedback{
               score: parse_score(params["score_" <> pa.attempt_guid]),
               out_of: AttemptState.out_of(pa, parts_map),
               feedback: String.trim(params["feedback_" <> pa.attempt_guid])
             }}
          end)

        case ManualGrading.apply_manual_scoring(section, attempt, score_feedbacks) do
          {:ok, _} ->
            saved_parts = AttemptState.part_attempts(attempt)
            saved = saved_values(saved_parts)

            {:noreply,
             socket
             |> put_flash(:info, "Score and feedback applied successfully.")
             |> assign(
               part_attempts: saved_parts,
               form_params: saved,
               readonly: true
             )
             |> recompute_position()}

          _ ->
            {:noreply, put_flash(socket, :error, "There was a problem scoring this attempt.")}
        end
    end
  end

  def handle_event("show_unsaved_changes_modal", _params, socket) do
    case editable_parts(socket.assigns.part_attempts) do
      # every part is already scored (an Apply landed before this request): nothing to lose
      [] -> {:noreply, push_event(socket, "unsaved_changes:proceed", %{})}
      _ -> {:noreply, assign(socket, show_unsaved_modal: true)}
    end
  end

  def handle_event("dismiss_unsaved_changes_modal", _, socket) do
    {:noreply, assign(socket, show_unsaved_modal: false)}
  end

  def handle_event("discard_and_leave", _, socket) do
    {:noreply,
     socket
     |> assign(show_unsaved_modal: false, form_params: %{})
     |> push_event("unsaved_changes:proceed", %{})}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  # If someone else scored the open submission, the next scoring event freezes the form
  # with the draft still visible (leaving asks for confirmation; Discard is accepted).
  defp revalidate_pending(%{assigns: %{readonly: true}} = socket), do: socket

  defp revalidate_pending(socket) do
    %{section: section, attempt: attempt} = socket.assigns

    case ManualGrading.fetch_submitted_attempt(section, attempt.id) do
      nil -> socket |> assign(readonly: true, not_awaiting: true) |> recompute_position()
      _ -> socket
    end
  end

  # The submission left the queue: the counter hides and Previous/Next come from the anchor.
  defp recompute_position(%{assigns: %{anchor: nil}} = socket), do: socket

  defp recompute_position(socket) do
    %{section: section, sorting: sorting, options: options, anchor: anchor} = socket.assigns
    assign(socket, position: ManualGrading.submission_position(section, sorting, options, anchor))
  end

  defp saved_values(part_attempts) do
    part_attempts
    |> manual_parts()
    |> Enum.flat_map(fn pa ->
      [
        {"score_" <> pa.attempt_guid, if(is_nil(pa.score), do: "", else: to_string(pa.score))},
        {"feedback_" <> pa.attempt_guid, saved_feedback(pa)}
      ]
    end)
    |> Map.new()
  end

  defp readonly_feedback(pa) do
    case {saved_feedback(pa), pa.grading_approach} do
      {"", :automatic} -> "This part was automatically graded by the system"
      {"", _manual} -> "No feedback provided"
      {feedback, _} -> feedback
    end
  end

  defp saved_feedback(pa) do
    pa
    |> Utils.extract_from_part_attempt()
    |> List.flatten()
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n")
  end
end
