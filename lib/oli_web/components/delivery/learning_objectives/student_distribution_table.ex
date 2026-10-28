defmodule OliWeb.Components.Delivery.LearningObjectives.StudentDistributionTable do
  @moduledoc """
  Renders the student list for the currently selected Student Distribution group, beside the
  matrix chart. Students can be selected via row checkboxes and a header "select all", and
  emailed via an `EmailButton`/`DraftEmailModal` forwarding pattern already used elsewhere in
  the app (the modal itself is rendered by a sibling component further up the tree, not here --
  see `email_modal_payload/2`).

  Renders its own `<table>` markup rather than reusing `OliWeb.Common.SortableTable.Table`:
  that shared component applies `additional_row_class` identically to every row (no real
  zebra striping), and its sortable `<th>` is a bare `phx-click`-bound element with no
  keyboard/`aria-sort` support. Hand-rolling here gets real per-row striping, accessible
  sortable headers, and a selection checkbox column without changing a component shared
  across the rest of the codebase.

  Never recomputes group membership: `students` must already carry `:distribution_group` and
  `:activity_completion` from `Oli.Delivery.Metrics.StudentDistributionGroup.assign/1`. This
  component only filters, sorts, and displays what it is given.

  The close ("X") control targets `parent_target` (the owning `ExpandedObjectiveView`'s
  `@myself`), not this component's own `@myself`, since deselecting a group is state owned by
  the parent. Sorting, the proficiency filter, selection, and Load More are all local state.
  """

  use OliWeb, :live_component

  alias Oli.Utils
  alias OliWeb.Common.Chip
  alias OliWeb.Components.Delivery.LearningObjectives.StudentDistributionTableModel
  alias OliWeb.Components.Delivery.Students.EmailButton
  alias OliWeb.Components.Delivery.Students.StudentSelection
  alias OliWeb.Components.Delivery.UserAccount
  alias OliWeb.Icons

  @visible_count_step 20
  @default_sort_by StudentDistributionTableModel.default_sort_by()
  @default_sort_order :asc
  @default_proficiency_filter "all"

  # The left accent border and header count badge both use each group's own accent color,
  # matched pixel-exact to existing tokens already wired for other proficiency/chart surfaces
  # in this codebase (no new tokens needed) -- Needs Support mirrors the "Low" chip treatment,
  # Excelling mirrors "High", Limited Activity mirrors the neutral/gray chip default. The
  # accent is a real `border-left` (overriding just that side's width/color on top of the
  # panel's own 1px `border`), not a separate overlay element -- CSS borders already respect
  # the panel's own `rounded-xl` corners for free.
  @group_content %{
    needs_support: %{
      title: "Needs Support",
      guidance:
        "Students are actively completing the linked learning activities, but are still " <>
          "unlikely to apply this learning objective. Review common misconceptions, " <>
          "additional practice materials, or reach out to students to offer support.",
      accent_border_class: "border-l-Border-border-danger",
      badge_bg_class: "bg-Fill-fill-danger",
      badge_text_class: "text-Text-text-danger"
    },
    excelling: %{
      title: "Excelling",
      guidance:
        "Students are actively completing the linked learning activities and are likely to " <>
          "apply this objective across linked activities.",
      accent_border_class: "border-l-Text-text-accent-green",
      badge_bg_class: "bg-Fill-Chip-Green",
      badge_text_class: "text-Text-text-accent-green"
    },
    limited_activity: %{
      title: "Limited Activity",
      guidance:
        "Students in this group have completed fewer activities related to this learning " <>
          "objective. Some may not yet have enough evidence for a proficiency estimate, " <>
          "while others may have demonstrated proficiency based on limited activity.",
      accent_border_class: "border-l-Text-text-high",
      badge_bg_class: "bg-Fill-Chip-Gray",
      badge_text_class: "text-Text-Chip-Gray"
    }
  }

  @proficiency_filter_options [
    {"Proficiency", "all"},
    {"Not Enough Info", "not_enough_info"},
    {"Low", "low"},
    {"Medium", "medium"},
    {"High", "high"}
  ]
  @valid_proficiency_filters Enum.map(@proficiency_filter_options, &elem(&1, 1))

  def update(assigns, socket) do
    group_changed? = socket.assigns[:selected_group] not in [nil, assigns.selected_group]

    socket =
      socket
      |> assign(assigns)
      |> reset_local_state_if_needed(group_changed?)

    # `update/2` runs on every render of the parent LiveComponent, not only when this
    # component's own inputs change (e.g. an unrelated search keystroke elsewhere on the
    # page). Only re-filter when the group changes (or on first mount); `load_more`/
    # `student_distribution_sort` below already keep the filtered list and only re-sort or
    # re-slice, so they never call this either. `students` itself never changes for an
    # already-mounted instance -- `ExpandedObjectiveView` computes it once per expanded
    # objective -- so there is no `students`-changed case to guard against here.
    socket =
      if group_changed? or not Map.has_key?(socket.assigns, :sorted_students) do
        socket |> recompute_filtered_students() |> resort() |> recompute_email_assigns()
      else
        socket
      end

    {:ok, socket}
  end

  defp reset_local_state_if_needed(socket, true) do
    socket
    |> assign(:sort_by, @default_sort_by)
    |> assign(:sort_order, @default_sort_order)
    |> assign(:selected_proficiency_filter, @default_proficiency_filter)
    |> assign(:visible_count, @visible_count_step)
    |> assign(:selected_student_ids, [])
  end

  defp reset_local_state_if_needed(socket, false) do
    socket
    |> assign_new(:sort_by, fn -> @default_sort_by end)
    |> assign_new(:sort_order, fn -> @default_sort_order end)
    |> assign_new(:selected_proficiency_filter, fn -> @default_proficiency_filter end)
    |> assign_new(:visible_count, fn -> @visible_count_step end)
    |> assign_new(:selected_student_ids, fn -> [] end)
  end

  def render(assigns) do
    content = Map.fetch!(@group_content, assigns.selected_group)
    visible_rows = Enum.take(assigns.sorted_students, assigns.visible_count)
    remaining_count = max(length(assigns.sorted_students) - length(visible_rows), 0)

    filtered_ids = Enum.map(assigns.sorted_students, & &1.id)
    # `selected_student_ids` stays list-based (the `StudentSelection` contract), but membership
    # is checked once per row here -- build a set for O(1) lookups instead of scanning the list.
    selected_id_set = MapSet.new(assigns.selected_student_ids)

    select_all_checked =
      filtered_ids != [] and Enum.all?(filtered_ids, &MapSet.member?(selected_id_set, &1))

    assigns =
      assigns
      |> assign(:content, content)
      |> assign(:filter_options, @proficiency_filter_options)
      |> assign(:columns, StudentDistributionTableModel.columns())
      |> assign(:filtered_student_count, length(assigns.sorted_students))
      |> assign(:remaining_count, remaining_count)
      |> assign(:visible_count_step, @visible_count_step)
      |> assign(:visible_rows, visible_rows)
      |> assign(:select_all_checked, select_all_checked)
      |> assign(:selected_id_set, selected_id_set)

    ~H"""
    <div
      id={@id}
      class={[
        "flex h-[625px] w-full flex-col rounded-xl border border-l-[3px] border-Border-border-subtle bg-Background-bg-secondary p-4",
        @content.accent_border_class
      ]}
    >
      <div class="mb-3 flex shrink-0 items-start justify-between gap-3">
        <div class="min-w-0">
          <div class="flex items-center gap-2">
            <span
              aria-label={"#{@group_student_count} #{ngettext("student", "students", @group_student_count)}"}
              class={[
                "inline-flex h-6 min-w-[24px] items-center justify-center rounded-full px-1.5 text-sm font-bold leading-none",
                @content.badge_bg_class,
                @content.badge_text_class
              ]}
            >
              {@group_student_count}
            </span>
            <h4 class="text-base font-bold leading-6 text-Text-text-high">{@content.title}</h4>
          </div>
          <p class="mt-1 text-sm leading-5 text-Text-text-low-alpha">{@content.guidance}</p>
        </div>
        <button
          type="button"
          aria-label={"Close #{@content.title} student list"}
          phx-click="deselect_student_group"
          phx-target={@parent_target}
          class="shrink-0 rounded-md p-1 text-Icon-icon-default hover:bg-Table-table-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
        >
          <Icons.close_sm />
          <span class="sr-only">Close</span>
        </button>
      </div>

      <div :if={@group_student_count > 0} class="mb-3 flex shrink-0 flex-wrap items-center gap-2">
        <.live_component
          id={"#{@id}-email-button"}
          module={EmailButton}
          selected_students={@selected_student_ids}
          selected_emails={@selected_emails}
          section_slug={@section_slug}
          instructor_email={@instructor_email}
          email_handler_id={@id}
          email_modal_payload={@email_modal_payload}
        />

        <.form for={%{}} phx-target={@myself} phx-change="filter_by_proficiency">
          <label for={"#{@id}-proficiency-filter"} class="sr-only">Filter by proficiency</label>
          <select
            id={"#{@id}-proficiency-filter"}
            name="proficiency"
            class="w-44 truncate overflow-hidden text-ellipsis whitespace-nowrap rounded-md border border-Border-border-default bg-Background-bg-primary py-1 pl-2 pr-8 text-sm text-Text-text-high focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
          >
            <option
              :for={{label, value} <- @filter_options}
              value={value}
              selected={value == @selected_proficiency_filter}
            >
              {label}
            </option>
          </select>
        </.form>
      </div>

      <%= if @filtered_student_count == 0 do %>
        <div
          data-role="empty-group-message"
          class="flex-1 rounded-lg border border-dashed border-Border-border-default p-4 text-sm text-Text-text-low"
        >
          {empty_state_message(@group_student_count)}
        </div>
      <% else %>
        <div class="min-h-0 flex-1 overflow-y-auto">
          <table class="w-full border-separate border-spacing-0 text-left text-sm">
            <caption class="sr-only">{@content.title} students</caption>
            <thead>
              <tr class="!border-0">
                <th
                  scope="col"
                  class="!sticky !top-0 z-10 w-10 border-b border-t border-Table-table-border !bg-Background-bg-secondary p-2"
                >
                  <label class="flex h-6 w-6 cursor-pointer items-center justify-center">
                    <input
                      type="checkbox"
                      checked={@select_all_checked}
                      phx-click="toggle_all"
                      phx-target={@myself}
                      aria-label={select_all_label(@select_all_checked, @filtered_student_count)}
                      class="h-4 w-4 rounded border-Border-border-default focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
                    />
                  </label>
                </th>
                <th
                  :for={col <- @columns}
                  scope="col"
                  class="!sticky !top-0 z-10 border-b border-t border-Table-table-border !bg-Background-bg-secondary p-2 font-semibold text-Text-text-high"
                  aria-sort={aria_sort(col.key, @sort_by, @sort_order)}
                >
                  <div class="inline-flex items-center gap-1">
                    <.header_tooltip
                      :if={col[:tooltip]}
                      id={"#{@id}-#{col.key}-tooltip"}
                      text={col.tooltip}
                    />
                    <button
                      type="button"
                      phx-click="student_distribution_sort"
                      phx-value-sort_by={col.key}
                      phx-target={@myself}
                      class="inline-flex items-center gap-1 rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
                    >
                      {col.label}
                      <Icons.chevron_down
                        width="16"
                        height="16"
                        class={[
                          "fill-Icon-icon-default",
                          col.key != @sort_by && "opacity-40",
                          (col.key == @sort_by and @sort_order == :asc) && "rotate-180"
                        ]}
                      />
                    </button>
                  </div>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={{student, index} <- Enum.with_index(@visible_rows)}
                id={"#{@id}-row-#{student.id}"}
                class={[
                  "border-b border-Table-table-border",
                  rem(index, 2) == 0 && "bg-Table-table-row-1",
                  rem(index, 2) == 1 && "bg-Table-table-row-2"
                ]}
              >
                <td class="p-2">
                  <label class="flex h-6 w-6 cursor-pointer items-center justify-center">
                    <input
                      type="checkbox"
                      checked={MapSet.member?(@selected_id_set, student.id)}
                      phx-click="toggle_student"
                      phx-value-student_id={student.id}
                      phx-target={@myself}
                      aria-label={"Select #{student.full_name}"}
                      class="h-4 w-4 rounded border-Border-border-default focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
                    />
                  </label>
                </td>
                <td class="p-2 text-Text-text-high">
                  <div class="flex items-center gap-2">
                    <UserAccount.user_picture_icon
                      user={%{name: student.full_name, picture: Map.get(student, :picture)}}
                      size_class="h-6 w-6 shrink-0"
                      initials_text_class="text-xs leading-3"
                    />
                    <span class="truncate">{student.full_name}</span>
                  </div>
                </td>
                <td class="p-2">
                  <.proficiency_chip student={student} />
                </td>
                <td class="p-2 text-Text-text-high">{activities_text(student)}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div :if={@remaining_count > 0} class="mt-3 shrink-0">
          <button
            type="button"
            phx-click="load_more"
            phx-target={@myself}
            data-role="load-more"
            class="rounded-md px-3 py-2 text-sm font-semibold text-Text-text-button hover:underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
          >
            Load {min(@remaining_count, @visible_count_step)} more ({@remaining_count} remaining)
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  # Similar intent to `OliWeb.Delivery.InstructorDashboard.HTMLComponents.render_label/1`'s
  # icon+tooltip, but not reused wholesale (that helper bundles the icon *and* the column
  # title into one block, while here only the title belongs inside the clickable sort
  # button) and made keyboard/AT-reachable: a real `<button>` trigger (not a bare `<span>`)
  # with `aria-describedby`, and a plain `role="tooltip"` `<div>` (not `<dialog>`, which stays
  # closed to assistive tech without an explicit `.showModal()`/`open`) shown on hover *or*
  # focus, not hover-only.
  attr :id, :string, required: true
  attr :text, :string, required: true

  defp header_tooltip(assigns) do
    ~H"""
    <span class="group relative inline-flex items-center">
      <button
        type="button"
        aria-describedby={@id}
        class="flex items-center text-Icon-icon-default focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
      >
        <Icons.info />
        <span class="sr-only">More info</span>
      </button>
      <div
        id={@id}
        role="tooltip"
        class="pointer-events-none absolute top-[150%] left-full z-10 hidden w-80 -translate-x-1/2 rounded-md border border-Border-border-default bg-Surface-surface-background px-4 py-2 text-left text-sm font-normal leading-normal text-Text-text-high shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] group-hover:block group-focus-within:block"
      >
        {@text}
      </div>
    </span>
    """
  end

  # No icon, unlike the shared `Proficiency.chip/1` used by other LO tables. Skips the tooltip
  # for "Not enough data" since its `:proficiency` is `0.0` upstream, not a real 0% score.
  attr :student, :map, required: true

  defp proficiency_chip(assigns) do
    label = assigns.student.proficiency_range || "Not enough data"
    {bg_color, text_color} = proficiency_chip_colors(label)

    assigns =
      assign(assigns,
        label: label,
        bg_color: bg_color,
        text_color: text_color,
        tooltip: proficiency_tooltip(assigns.student, label)
      )

    ~H"""
    <Chip.render
      label={@label}
      bg_color={@bg_color}
      text_color={@text_color}
      label_class="whitespace-nowrap"
      tooltip={@tooltip}
    />
    """
  end

  defp proficiency_chip_colors("High"), do: {"bg-Fill-Chip-Green", "text-Text-text-accent-green"}

  defp proficiency_chip_colors("Medium"),
    do: {"bg-Fill-Accent-fill-accent-orange", "text-Text-Chip-Orange"}

  defp proficiency_chip_colors("Low"), do: {"bg-Fill-fill-danger", "text-Text-text-danger"}
  defp proficiency_chip_colors(_), do: {"bg-Fill-Chip-Gray", "text-Text-Chip-Gray"}

  defp proficiency_tooltip(_student, "Not enough data"), do: nil

  defp proficiency_tooltip(student, _label) do
    case Map.get(student, :proficiency) do
      proficiency when is_number(proficiency) -> "#{round(proficiency * 100)}% proficiency"
      _ -> nil
    end
  end

  def handle_event("filter_by_proficiency", %{"proficiency" => proficiency}, socket) do
    {:noreply,
     socket
     |> assign(:selected_proficiency_filter, normalize_proficiency_filter(proficiency))
     |> assign(:visible_count, @visible_count_step)
     |> recompute_filtered_students()
     |> resort()}
  end

  def handle_event("filter_by_proficiency", _params, socket), do: {:noreply, socket}

  # Load More never changes which students are in view (group and proficiency filter are
  # unchanged) or how they're sorted -- it only widens how many of the already-filtered,
  # already-sorted rows `render/1` slices, so no re-filter/re-sort is needed here.
  def handle_event("load_more", _params, socket) do
    {:noreply, assign(socket, :visible_count, socket.assigns.visible_count + @visible_count_step)}
  end

  def handle_event("student_distribution_sort", %{"sort_by" => sort_by_param}, socket) do
    sort_by = parse_sort_by(sort_by_param)

    sort_order =
      if sort_by == socket.assigns.sort_by do
        if socket.assigns.sort_order == :asc, do: :desc, else: :asc
      else
        :asc
      end

    {:noreply,
     socket
     |> assign(:sort_by, sort_by)
     |> assign(:sort_order, sort_order)
     |> resort()}
  end

  def handle_event("student_distribution_sort", _params, socket), do: {:noreply, socket}

  def handle_event("toggle_student", %{"student_id" => student_id_param}, socket) do
    case Integer.parse(student_id_param) do
      {student_id, ""} ->
        updated = StudentSelection.toggle(socket.assigns.selected_student_ids, student_id)

        {:noreply, socket |> assign(:selected_student_ids, updated) |> recompute_email_assigns()}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_student", _params, socket), do: {:noreply, socket}

  # Selects/deselects every currently filtered student (not just the currently-visible,
  # paginated slice), so selection stays consistent as more rows are revealed via Load More.
  def handle_event("toggle_all", _params, socket) do
    %{sorted_students: sorted_students, selected_student_ids: selected} = socket.assigns
    filtered_ids = Enum.map(sorted_students, & &1.id)

    updated = StudentSelection.toggle_all(filtered_ids, selected)

    {:noreply, socket |> assign(:selected_student_ids, updated) |> recompute_email_assigns()}
  end

  defp recompute_filtered_students(socket) do
    %{
      students: students,
      selected_group: group,
      selected_proficiency_filter: proficiency_filter
    } = socket.assigns

    group_students = Enum.filter(students, &(Map.get(&1, :distribution_group) == group))
    filtered_students = filter_by_proficiency(group_students, proficiency_filter)

    socket
    |> assign(:group_student_count, length(group_students))
    |> assign(:filtered_students, filtered_students)
  end

  # Re-sorts the already group/proficiency-filtered list. Called both when the filter itself
  # changed (via `recompute_filtered_students/1` first) and when only the sort column/order
  # changed, so it never re-runs the `Enum.filter/2` passes unless the filter actually did.
  defp resort(socket) do
    %{
      filtered_students: filtered_students,
      selected_group: group,
      sort_by: sort_by,
      sort_order: sort_order
    } = socket.assigns

    sorted_students =
      StudentDistributionTableModel.sort(filtered_students, group, sort_by, sort_order)

    assign(socket, :sorted_students, sorted_students)
  end

  defp filter_by_proficiency(students, "all"), do: students

  defp filter_by_proficiency(students, filter) do
    label = proficiency_label_for_filter(filter)
    Enum.filter(students, &(Map.get(&1, :proficiency_range) == label))
  end

  defp proficiency_label_for_filter("not_enough_info"), do: "Not enough data"
  defp proficiency_label_for_filter("low"), do: "Low"
  defp proficiency_label_for_filter("medium"), do: "Medium"
  defp proficiency_label_for_filter("high"), do: "High"

  defp normalize_proficiency_filter(filter) when filter in @valid_proficiency_filters, do: filter
  defp normalize_proficiency_filter(_filter), do: @default_proficiency_filter

  defp parse_sort_by(sort_by) do
    Enum.find(
      StudentDistributionTableModel.sortable_columns(),
      @default_sort_by,
      &(Atom.to_string(&1) == sort_by)
    )
  end

  defp aria_sort(col_key, sort_by, _sort_order) when col_key != sort_by, do: "none"
  defp aria_sort(_col_key, _sort_by, :asc), do: "ascending"
  defp aria_sort(_col_key, _sort_by, :desc), do: "descending"

  defp select_all_label(true, count), do: "Deselect all (#{count} students)"
  defp select_all_label(false, count), do: "Select all (#{count} students)"

  defp activities_text(student) do
    attempted = Map.get(student, :activities_attempted_count) || 0
    total = Map.get(student, :total_related_activities) || 0
    pct = Map.get(student, :activity_completion) || 0.0
    "#{attempted} of #{total} (#{round(pct * 100)}%)"
  end

  defp empty_state_message(0), do: "No students currently belong to this group."
  defp empty_state_message(_group_student_count), do: "No students match the selected filter."

  # Recomputes the two assigns derived from the current selection (`selected_emails`,
  # `email_modal_payload`) -- called from `update/2` (group change / first mount) and from the
  # two selection-toggling event handlers, never from `render/1`, so sorting/filtering/Load
  # More (which never touch selection) don't pay for a fresh scan of `students`.
  defp recompute_email_assigns(socket) do
    %{students: students, selected_student_ids: selected_student_ids, selected_group: group} =
      socket.assigns

    content = Map.fetch!(@group_content, group)
    recipients = StudentSelection.recipients(students, selected_student_ids, & &1.full_name)

    selected_emails =
      recipients
      |> Enum.map(& &1.email)
      |> Utils.normalize_and_join_strings(", ", unique: true)

    socket
    |> assign(:selected_emails, selected_emails)
    |> assign(:email_modal_payload, email_modal_payload(socket.assigns, content, recipients))
  end

  # Shaped to match `DraftEmailModal`'s expected assigns exactly, so `LearningObjectives` can
  # forward it with a plain `{@email_modal_payload}` splat once `EmailButton` relays it up
  # through `instructor_dashboard_live.ex`. `objective`'s `proficiency_label` uses the group's
  # own title (e.g. "Needs Support") rather than a single proficiency label, since a
  # distribution group can span multiple proficiency ranges.
  defp email_modal_payload(assigns, content, recipients) do
    %{
      students: recipients,
      section_id: assigns.section_id,
      section_title: assigns.section_title,
      section_slug: assigns.section_slug,
      instructor_email: assigns.instructor_email,
      instructor_name: assigns.instructor_name,
      situation_key: situation_key(assigns.selected_group),
      scope_label: content.title,
      objective: %{title: assigns.objective_title, proficiency_label: content.title}
    }
  end

  defp situation_key(:needs_support), do: :struggling_students
  defp situation_key(:excelling), do: :excelling_students
  defp situation_key(:limited_activity), do: :inactive_students
end
