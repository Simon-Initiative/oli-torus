defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.StudentSupportTile do
  @moduledoc """
  Student Support tile surface for `MER-5252`.
  """

  use OliWeb, :live_component
  alias OliWeb.Icons
  alias OliWeb.Components.DesignTokens.Primitives.Button
  alias OliWeb.Components.Delivery.UserAccount
  alias OliWeb.Components.Delivery.Students.EmailButton

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.StudentSupportEmailModal

  @bucket_styles %{
    "struggling" => %{
      chart: %{light: "#A44A09", dark: "#FF9C54"},
      accent_class: "bg-Fill-Chart-fill-chart-orange-active",
      dot_class: "bg-Fill-Chart-fill-chart-orange-active",
      dot_muted_class: "bg-Fill-Chart-fill-chart-orange-muted",
      dot_hover_class: "group-hover:bg-Fill-Chart-fill-chart-orange-active",
      chip_class: "bg-Fill-Chart-fill-chart-orange-active text-white dark:text-zinc-700",
      chip_hover_bg_class: "group-hover:bg-Fill-Chart-fill-chart-orange-active",
      chip_hover_text_class: "group-hover:text-white dark:group-hover:text-zinc-700"
    },
    "on_track" => %{
      chart: %{light: "#00626F", dark: "#39D3E5"},
      accent_class: "bg-Fill-Chart-fill-chart-blue-active",
      dot_class: "bg-Fill-Chart-fill-chart-blue-active",
      dot_muted_class: "bg-Fill-Chart-fill-chart-blue-muted",
      dot_hover_class: "group-hover:bg-Fill-Chart-fill-chart-blue-active",
      chip_class: "bg-Fill-Chart-fill-chart-blue-active text-white dark:text-zinc-700",
      chip_hover_bg_class: "group-hover:bg-Fill-Chart-fill-chart-blue-active",
      chip_hover_text_class: "group-hover:text-white dark:group-hover:text-zinc-700"
    },
    "excelling" => %{
      chart: %{light: "#86199C", dark: "#DC6DF2"},
      accent_class: "bg-Fill-Chart-fill-chart-purple-active",
      dot_class: "bg-Fill-Chart-fill-chart-purple-active",
      dot_muted_class: "bg-Fill-Chart-fill-chart-purple-muted",
      dot_hover_class: "group-hover:bg-Fill-Chart-fill-chart-purple-active",
      chip_class: "bg-Fill-Chart-fill-chart-purple-active text-white dark:text-zinc-700",
      chip_hover_bg_class: "group-hover:bg-Fill-Chart-fill-chart-purple-active",
      chip_hover_text_class: "group-hover:text-white dark:group-hover:text-zinc-700"
    },
    "not_enough_information" => %{
      chart: %{light: "#757682", dark: "#524D59"},
      accent_class: "bg-Fill-Accent-fill-accent-grey",
      dot_class: "bg-Icon-icon-default",
      dot_muted_class: "bg-Fill-Accent-fill-accent-grey",
      dot_hover_class: "group-hover:bg-Icon-icon-default",
      chip_class: "bg-Icon-icon-default text-white dark:text-black",
      chip_hover_bg_class: "group-hover:bg-Icon-icon-default",
      chip_hover_text_class: "group-hover:text-white dark:group-hover:text-black"
    }
  }
  @chart_bucket_order ["struggling", "excelling", "on_track", "not_enough_information"]
  @chart_theme_styles %{
    separator: %{light: "#FFFFFF", dark: "#1B191F"},
    # Border-border-active token
    border_active: %{light: "#353740", dark: "#EEEBF5"}
  }

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    projection = Map.get(assigns, :projection, socket.assigns[:projection] || %{})
    tile_state = Map.get(assigns, :tile_state, socket.assigns[:tile_state] || %{})
    visible_students = current_visible_students(projection, tile_state)
    projection_signature = projection_signature(projection, tile_state)
    student_lookup = student_lookup(projection)

    selected_student_ids =
      case socket.assigns[:student_support_projection_signature] do
        ^projection_signature ->
          normalize_selected_student_ids(socket.assigns[:selected_student_ids])

        _ ->
          []
      end

    show_email_modal =
      Map.get(assigns, :show_email_modal, socket.assigns[:show_email_modal] || false) and
        selected_student_ids != []

    selected_students_data = selected_students_data(student_lookup, selected_student_ids)
    selected_emails = selected_student_emails(selected_students_data)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:visible_students, visible_students)
     |> assign(:student_lookup, student_lookup)
     |> assign(:student_support_projection_signature, projection_signature)
     |> assign(:selected_student_ids, selected_student_ids)
     |> assign(:selected_students_data, selected_students_data)
     |> assign(:selected_emails, selected_emails)
     |> assign(:show_email_modal, show_email_modal)}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    projection = Map.get(assigns, :projection, %{})
    tile_state = Map.get(assigns, :tile_state, %{})
    selected_bucket_id = selected_bucket_id(projection, tile_state)
    buckets = Map.get(projection, :buckets, [])
    selected_bucket = Enum.find(buckets, &(&1.id == selected_bucket_id))
    selected_filter = Map.get(tile_state, :selected_activity_filter, :all)
    search_term = Map.get(tile_state, :search_term, "")
    visible_count = Map.get(tile_state, :visible_count, 20)
    filtered_students = filter_students(selected_bucket, selected_filter, search_term)
    visible_students = Enum.take(filtered_students, visible_count)
    remaining_count = max(length(filtered_students) - length(visible_students), 0)
    compact_graph_keys? = compact_graph_keys?(buckets)
    selected_student_ids = normalize_selected_student_ids(assigns[:selected_student_ids])

    select_all_checked =
      visible_students != [] and Enum.all?(visible_students, &selected?(&1, selected_student_ids))

    assigns =
      assigns
      |> assign(:bucket_styles, @bucket_styles)
      |> assign(:projection, projection)
      |> assign(:buckets, buckets)
      |> assign(:selected_bucket_id, selected_bucket_id)
      |> assign(:selected_bucket, selected_bucket)
      |> assign(:selected_filter, selected_filter)
      |> assign(:search_term, search_term)
      |> assign(:filtered_students, filtered_students)
      |> assign(:visible_students, visible_students)
      |> assign(:remaining_count, remaining_count)
      |> assign(:selected_student_ids, selected_student_ids)
      |> assign(:select_all_checked, select_all_checked)
      |> assign(:compact_graph_keys?, compact_graph_keys?)
      |> assign(:chart_spec, build_chart_spec(buckets, selected_bucket_id))
      |> assign(:chart_colors, chart_colors())
      |> assign(:chart_theme_styles, @chart_theme_styles)

    ~H"""
    <article
      id="learning-dashboard-student-support-tile"
      data-dashboard-width-mode="normal"
      data-dashboard-width-aware
      class="h-full rounded-xl border border-Border-border-subtle bg-Surface-surface-primary p-3 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]"
    >
      <div class="mb-4 space-y-2 px-1 pt-1">
        <div class="flex items-start justify-between gap-4">
          <div class="flex items-center gap-2">
            <Icons.person class="fill-Text-text-high" />
            <h3 class="text-lg font-semibold leading-6 text-Text-text-high">Student Support</h3>
          </div>
          <.link
            navigate={~p"/sections/#{@section_slug}/instructor_dashboard/overview/students"}
            class="pt-1 text-sm font-bold leading-4 text-Text-text-button hover:underline"
          >
            View Student Overview
          </.link>
        </div>
        <p class="max-w-[42rem] text-sm leading-6 text-Text-text-low">
          Filter students by progress and proficiency to identify who needs support or is excelling.
        </p>
      </div>

      <%= cond do %>
        <% not projection_ready?(@projection) -> %>
          <div class="rounded-xl border border-Border-border-subtle bg-Background-bg-primary p-5 text-sm leading-6 text-Text-text-low">
            Loading student support data...
          </div>
        <% no_activity?(@projection) -> %>
          <div class="rounded-xl border border-Border-border-subtle bg-Background-bg-primary p-5 text-sm leading-6 text-Text-text-low">
            Student support insights will appear once students begin engaging. Students with no activity
            will appear with an inactivity indicator once the course begins.
          </div>
        <% true -> %>
          <div
            data-dashboard-width-aware
            class="grid gap-3 xl:grid-cols-[minmax(0,0.96fr)_minmax(0,1.04fr)] data-[dashboard-width-mode=narrow]:gap-2"
          >
            <div
              data-dashboard-width-aware
              class="flex flex-col items-center rounded-xl bg-Surface-surface-primary px-1 pb-2 data-[dashboard-width-mode=narrow]:px-0"
            >
              <div
                id={"student-support-chart-#{@id}"}
                phx-hook="StudentSupportChart"
                data-spec={Jason.encode!(@chart_spec)}
                data-colors={Jason.encode!(@chart_colors)}
                data-theme-styles={Jason.encode!(@chart_theme_styles)}
                data-chart-target={"student-support-chart-canvas-#{@id}"}
                data-dashboard-width-aware
                class="mx-auto flex min-h-[360px] w-full justify-center data-[dashboard-width-mode=narrow]:min-h-[300px] data-[dashboard-width-mode=narrow]:max-w-[270px]"
              >
                <div
                  id={"student-support-chart-canvas-#{@id}"}
                  phx-update="ignore"
                  data-dashboard-width-aware
                  class="flex min-h-[360px] w-full justify-center data-[dashboard-width-mode=narrow]:min-h-[300px]"
                >
                </div>
              </div>

              <div
                data-dashboard-width-aware
                class={[
                  "mx-auto mt-2 grid w-full gap-2",
                  "data-[dashboard-width-mode=narrow]:max-w-[270px] data-[dashboard-width-mode=narrow]:gap-1 data-[dashboard-width-mode=narrow]:grid-cols-1",
                  @compact_graph_keys? && "max-w-[385px] grid-cols-1",
                  !@compact_graph_keys? &&
                    "max-w-[360px] grid-cols-1 sm:grid-cols-2 xl:grid-cols-1 2xl:grid-cols-2"
                ]}
              >
                <%= for bucket <- @buckets do %>
                  <.graph_key
                    bucket={bucket}
                    selected_bucket_id={@selected_bucket_id}
                    compact_graph_keys?={@compact_graph_keys?}
                    style_map={bucket_style(bucket.id)}
                    patch_path={tile_patch_path(assigns, %{"bucket" => bucket.id, "page" => 1})}
                  />
                <% end %>
              </div>
            </div>

            <div
              data-dashboard-width-aware
              class="relative rounded-xl bg-Surface-surface-secondary p-3 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)] data-[dashboard-width-mode=narrow]:p-2.5"
            >
              <div class={[
                "absolute inset-y-0 left-0 w-[3px] rounded-l-xl",
                bucket_accent_class(@selected_bucket_id)
              ]}>
              </div>
              <div class="space-y-3 data-[dashboard-width-mode=narrow]:space-y-2.5">
                <div
                  data-dashboard-width-aware
                  class="space-y-1.5 data-[dashboard-width-mode=narrow]:space-y-1"
                >
                  <div class="flex items-start justify-between gap-2">
                    <p class="text-[18px] font-semibold leading-6 text-Text-text-high">
                      {bucket_title(@selected_bucket)}
                    </p>
                    <p class="pt-1 text-sm font-bold leading-4">
                      <span class="text-Text-text-high">
                        {bucket_student_count(@selected_bucket)}
                      </span>
                      <span class="text-Text-text-low-alpha">
                        /{bucket_total_students(@projection)} Students
                      </span>
                    </p>
                  </div>
                  <div class="space-y-1">
                    <%= for {row, idx} <- Enum.with_index(bucket_threshold_rows(@selected_bucket_id)) do %>
                      <div class="flex flex-wrap items-center gap-1.5 text-sm leading-4 text-Text-text-low-alpha">
                        <span>{row.label}</span>
                        <%= for {chip, chip_idx} <- Enum.with_index(row.chips) do %>
                          <%= if chip_idx > 0 do %>
                            <span>OR</span>
                          <% end %>
                          <span class={[
                            "rounded-md px-3 py-1 text-sm font-medium leading-4",
                            bucket_threshold_chip_class(@selected_bucket_id)
                          ]}>
                            {chip}
                          </span>
                        <% end %>
                        <button
                          :if={idx == 0}
                          type="button"
                          phx-click="edit_threshold_definitions"
                          phx-target={@myself}
                          class="inline-flex h-5 w-5 items-center justify-center text-Icon-icon-default"
                          aria-label="Edit threshold definitions"
                        >
                          <Icons.edit class="h-4 w-4 stroke-Icon-icon-default" />
                        </button>
                      </div>
                    <% end %>
                  </div>
                </div>

                <form phx-change="student_support_search_changed">
                  <label for={"student-support-search-#{@id}"} class="sr-only">
                    Search students in the current bucket
                  </label>
                  <div class="relative flex items-center gap-2 rounded-md border border-Border-border-default bg-Background-bg-primary px-3 py-2 shadow-[0px_2px_4px_0px_rgba(0,52,99,0.1)]">
                    <Icons.search />
                    <input
                      id={"student-support-search-#{@id}"}
                      type="text"
                      name="value"
                      value={@search_term}
                      phx-debounce="300"
                      placeholder="Search students..."
                      aria-label="Search students in the current bucket"
                      class={[
                        "w-full border-0 !bg-transparent p-0 text-sm text-Text-text-high placeholder:text-Text-text-low focus:outline-none focus:ring-0",
                        @search_term not in ["", nil] && "pr-7"
                      ]}
                    />
                    <.link
                      :if={@search_term not in ["", nil]}
                      patch={tile_patch_path(assigns, %{"q" => nil, "page" => 1})}
                      aria-label="Clear search"
                      class="absolute right-3 inline-flex h-4 w-4 cursor-pointer items-center justify-center rounded-sm text-Icon-icon-default hover:text-Text-text-high focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
                    >
                      <Icons.close_sm class="h-4 w-4 stroke-current" />
                    </.link>
                  </div>
                </form>

                <div class="flex flex-wrap items-center gap-1.5">
                  <.filter_button
                    value="active"
                    label="Active"
                    count={activity_count(@selected_bucket, :active)}
                    selected={active_selected?(@selected_filter)}
                    patch_path={
                      tile_patch_path(assigns, filter_patch_updates(@selected_filter, :active))
                    }
                  />
                  <.filter_button
                    value="inactive"
                    label="Inactive"
                    count={activity_count(@selected_bucket, :inactive)}
                    selected={inactive_selected?(@selected_filter)}
                    with_dot={true}
                    patch_path={
                      tile_patch_path(assigns, filter_patch_updates(@selected_filter, :inactive))
                    }
                  />
                </div>

                <div class="flex items-center justify-between gap-2 px-2">
                  <div class="inline-flex items-center gap-2">
                    <.selection_checkbox
                      checked={@select_all_checked}
                      on_click="select_all_students"
                      target={@myself}
                      label="Select all visible students"
                    />
                    <span class="text-sm font-semibold leading-4 text-Text-text-low-alpha">
                      Select All
                    </span>
                  </div>
                  <.live_component
                    id={"student_support_email_button_#{@dashboard_scope}_#{@id}"}
                    module={EmailButton}
                    variant={:minimal}
                    selected_students={@selected_student_ids}
                    selected_emails={@selected_emails}
                    section_slug={@section_slug}
                    instructor_email={@instructor_email}
                    email_handler_id={@id}
                  />
                </div>

                <div class="h-[248px] space-y-0 overflow-y-auto pr-1">
                  <%= for {student, index} <- Enum.with_index(@visible_students) do %>
                    <div class={[
                      "group relative flex items-center justify-between gap-3 border-b border-Border-border-default px-2 py-2 transition-colors hover:border-Border-border-hover hover:bg-Table-table-hover focus-within:border-Border-border-hover",
                      rem(index, 2) == 0 && "bg-Surface-surface-primary",
                      rem(index, 2) == 1 && "bg-Surface-surface-secondary"
                    ]}>
                      <div class="min-w-0 flex flex-1 items-center gap-2">
                        <.selection_checkbox
                          checked={selected?(student, @selected_student_ids)}
                          on_click="student_support_row_toggled"
                          target={@myself}
                          value={student.id}
                          label={"Select #{student.display_name}"}
                        />
                        <div class="relative h-6 w-6 shrink-0">
                          <UserAccount.user_picture_icon
                            user={%{name: student.display_name, picture: Map.get(student, :picture)}}
                            size_class="h-6 w-6"
                            initials_text_class="text-xs leading-3"
                          />
                          <%= if student.activity_status == :inactive do %>
                            <span class="absolute -bottom-0.5 -right-0.5 h-2.5 w-2.5 rounded-full bg-[#F28482] ring-1 ring-Surface-surface-primary">
                            </span>
                          <% end %>
                        </div>
                        <div class="min-w-0 flex-1 transition-[padding-right] group-hover:pr-[152px]">
                          <p class="truncate text-base font-medium leading-6 text-Text-text-low">
                            {student.display_name}
                          </p>
                        </div>
                      </div>
                      <div class="pointer-events-none absolute inset-y-0 right-2 flex items-center justify-end">
                        <Button.button
                          navigate={student_profile_path(@section_slug, student)}
                          variant={:secondary}
                          size={:sm}
                          aria-label={"View profile for #{student.display_name}"}
                          data-role="view-profile"
                          class="pointer-events-none opacity-0 transition-opacity group-hover:pointer-events-auto group-hover:opacity-100 !bg-Fill-Buttons-fill-secondary-hover !text-Text-text-button-hover [html:not(.dark)_&]:!text-Specially-Tokens-Text-text-button-primary-hover !border-transparent !shadow-[0px_2px_6px_0px_rgba(0,52,99,0.15)] hover:!bg-Fill-Buttons-fill-secondary-hover hover:!text-Text-text-button-hover [html:not(.dark)_&:hover]:!text-Specially-Tokens-Text-text-button-primary-hover hover:!border-transparent"
                        >
                          View Profile
                        </Button.button>
                      </div>
                    </div>
                  <% end %>
                </div>

                <%= if @visible_students == [] do %>
                  <div class="rounded-lg border border-dashed border-Border-border-default p-4 text-sm text-Text-text-low">
                    No students match this filter.
                  </div>
                <% end %>

                <%= if @remaining_count > 0 do %>
                  <.link
                    patch={
                      tile_patch_path(assigns, %{
                        "page" => Map.get(assigns.tile_state, :page, 1) + 1
                      })
                    }
                    data-role="load-more"
                    class="inline-flex cursor-pointer rounded-md px-6 py-2 text-sm font-semibold text-Text-text-button"
                  >
                    Load {min(@remaining_count, 20)} more ({@remaining_count} remaining)
                  </.link>
                <% end %>

                <.live_component
                  :if={@show_email_modal}
                  id={"student_support_email_modal_#{@id}"}
                  module={StudentSupportEmailModal}
                  students={@selected_students_data}
                  section_title={@section_title}
                  instructor_email={@instructor_email}
                  instructor_name={@instructor_name}
                  section_slug={@section_slug}
                  selected_bucket_id={@selected_bucket_id}
                  show_modal={@show_email_modal}
                  email_handler_id={@id}
                  modal_dom_id={"student_support_email_modal_#{@id}"}
                />
              </div>
            </div>
          </div>
      <% end %>
    </article>
    """
  end

  attr :value, :string, required: true
  attr :label, :string, required: true
  attr :count, :integer, required: true
  attr :selected, :boolean, default: false
  attr :with_dot, :boolean, default: false
  attr :patch_path, :string, required: true

  defp filter_button(assigns) do
    ~H"""
    <.link
      patch={@patch_path}
      data-filter={@value}
      aria-label={filter_button_label(@label, @count, @selected, @with_dot)}
      title={inactive_tooltip(@label)}
      class={[
        "inline-flex cursor-pointer items-center gap-1 rounded-[3px] border px-[10px] py-[5px] text-base font-semibold leading-6 transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary",
        @selected &&
          "border-Text-text-button bg-Background-bg-primary text-Text-text-button",
        !@selected &&
          "border-Border-border-default bg-Background-bg-primary",
        !@selected && !@with_dot && "text-Text-text-low",
        !@selected && @with_dot && "text-Text-text-high"
      ]}
    >
      <%= if @with_dot do %>
        <span class="h-[11px] w-[11px] rounded-full bg-Fill-Chart-fill-chart-red-active"></span>
      <% end %>
      {@label} ({@count}) <span :if={@selected} class="sr-only">(selected)</span>
      <span :if={@label == "Inactive"} class="sr-only">
        Inactive means no activity in the past 7 days.
      </span>
    </.link>
    """
  end

  attr :checked, :boolean, default: false
  attr :on_click, :string, required: true
  attr :target, :any, required: true
  attr :value, :any, default: nil
  attr :label, :string, required: true

  defp selection_checkbox(assigns) do
    ~H"""
    <button
      type="button"
      role="checkbox"
      aria-checked={to_string(@checked)}
      aria-label={@label}
      phx-click={@on_click}
      phx-target={@target}
      phx-value-student_id={@value}
      class="inline-flex h-6 w-6 shrink-0 cursor-pointer items-center justify-center rounded-[3px] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
    >
      <span class={[
        "inline-flex h-5 w-5 items-center justify-center rounded-[3px] border",
        @checked &&
          "border-transparent bg-Fill-Buttons-fill-primary text-Icon-icon-white",
        !@checked &&
          "border-2 border-Border-border-default bg-Background-bg-primary text-transparent"
      ]}>
        <Icons.checkmark class="h-4 w-4" />
      </span>
    </button>
    """
  end

  attr :bucket, :map, required: true
  attr :selected_bucket_id, :string, required: true
  attr :compact_graph_keys?, :boolean, default: false
  attr :style_map, :map, required: true
  attr :patch_path, :string, required: true

  defp graph_key(assigns) do
    selected = assigns.bucket.id == assigns.selected_bucket_id
    display_count = graph_key_count(assigns.bucket)
    display_pct = graph_key_pct(assigns.bucket)

    assigns = assign(assigns, :selected, selected)
    assigns = assign(assigns, :display_count, display_count)
    assigns = assign(assigns, :display_pct, display_pct)

    ~H"""
    <.link
      patch={@patch_path}
      data-dashboard-width-aware
      data-bucket-id={@bucket.id}
      aria-label={graph_key_aria_label(@bucket, @display_count, @display_pct, @selected)}
      class={[
        "group cursor-pointer items-center gap-[5px] rounded-[3px] p-[6px] transition no-underline hover:no-underline focus:no-underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary",
        "data-[dashboard-width-mode=narrow]:gap-[4px] data-[dashboard-width-mode=narrow]:px-[4px] data-[dashboard-width-mode=narrow]:py-[5px]",
        @compact_graph_keys? && "flex w-full min-w-0 justify-between",
        !@compact_graph_keys? && "grid w-full min-w-0 grid-cols-[minmax(0,1fr)_auto_auto]",
        @selected && "bg-Fill-Chip-Gray",
        !@selected && "bg-transparent hover:bg-Surface-surface-secondary-hover"
      ]}
    >
      <span class={[
        "inline-flex items-center gap-1 rounded-md px-2 py-1 whitespace-nowrap",
        "data-[dashboard-width-mode=narrow]:px-1",
        @compact_graph_keys? && "min-w-[68px]",
        !@compact_graph_keys? && "min-w-0",
        graph_key_label_width_class(@bucket.id)
      ]}>
        <span
          class={[
            "h-[9px] w-[9px] rounded-full",
            @selected && @style_map.dot_class,
            !@selected && @style_map.dot_muted_class,
            !@selected && @style_map.dot_hover_class
          ]}
          style="flex-shrink: 0;"
        >
        </span>
        <span class="text-sm font-medium leading-4 text-Text-text-high whitespace-nowrap">
          {graph_key_label(@bucket)}
        </span>
      </span>
      <span class={[
        "shrink-0 rounded-md px-2 py-1 text-sm font-medium leading-4 whitespace-nowrap",
        "data-[dashboard-width-mode=narrow]:px-1.5",
        @selected && @style_map.chip_class,
        !@selected && "bg-Fill-fill-transparent text-Text-text-high",
        !@selected && @style_map.chip_hover_bg_class,
        !@selected && @style_map.chip_hover_text_class
      ]}>
        {@display_count}
      </span>
      <span class="shrink-0 text-sm font-medium leading-4 text-Text-text-high whitespace-nowrap">
        {@display_pct}%
      </span>
      <span :if={@selected} class="sr-only">(selected)</span>
    </.link>
    """
  end

  defp graph_key_count(bucket), do: bucket.count

  defp graph_key_pct(bucket), do: Float.round(bucket.pct * 100.0, 1)

  defp compact_graph_keys?(buckets) do
    Enum.any?(buckets, fn bucket ->
      label = graph_key_label(bucket)
      count = graph_key_count(bucket)
      pct = graph_key_pct(bucket)

      # Keep original Figma layout unless text payload gets too wide for the 2-column slot.
      String.length(label) + String.length(to_string(count)) + String.length(to_string(pct)) >= 16
    end)
  end

  defp selected_bucket_id(projection, tile_state) do
    selected_bucket_id = Map.get(tile_state, :selected_bucket_id)
    bucket_ids = projection |> Map.get(:buckets, []) |> Enum.map(& &1.id)

    cond do
      selected_bucket_id in bucket_ids -> selected_bucket_id
      true -> Map.get(projection, :default_bucket_id)
    end
  end

  defp filter_students(nil, _selected_filter, _search_term), do: []

  defp filter_students(bucket, selected_filter, search_term) do
    bucket
    |> Map.get(:students, [])
    |> maybe_filter_by_activity(selected_filter)
    |> maybe_filter_by_search(search_term)
  end

  defp maybe_filter_by_activity(students, :all), do: students

  defp maybe_filter_by_activity(students, filter) do
    Enum.filter(students, &(&1.activity_status == filter))
  end

  defp maybe_filter_by_search(students, ""), do: students

  defp maybe_filter_by_search(students, search_term) do
    query = String.downcase(search_term)

    Enum.filter(students, fn student ->
      String.contains?(Map.get(student, :searchable_text, ""), query)
    end)
  end

  @impl Phoenix.LiveComponent
  def handle_event("select_all_students", _params, socket) do
    visible_student_ids =
      (socket.assigns[:visible_students] || [])
      |> Enum.map(& &1.id)

    selected_student_ids = normalize_selected_student_ids(socket.assigns[:selected_student_ids])

    next_selected_student_ids =
      if visible_student_ids != [] and
           Enum.all?(visible_student_ids, &(&1 in selected_student_ids)) do
        selected_student_ids -- visible_student_ids
      else
        Enum.uniq(selected_student_ids ++ visible_student_ids)
      end

    selected_students_data =
      selected_students_data(socket.assigns.student_lookup, next_selected_student_ids)

    {:noreply,
     socket
     |> assign(:selected_student_ids, next_selected_student_ids)
     |> assign(:selected_students_data, selected_students_data)
     |> assign(:selected_emails, selected_student_emails(selected_students_data))
     |> assign(:show_email_modal, false)}
  end

  def handle_event("student_support_row_toggled", %{"student_id" => student_id}, socket) do
    case Integer.parse(student_id) do
      {parsed_student_id, ""} ->
        selected_student_ids =
          normalize_selected_student_ids(socket.assigns[:selected_student_ids])

        next_selected_student_ids =
          if parsed_student_id in selected_student_ids do
            List.delete(selected_student_ids, parsed_student_id)
          else
            [parsed_student_id | selected_student_ids]
          end

        selected_students_data =
          selected_students_data(socket.assigns.student_lookup, next_selected_student_ids)

        {:noreply,
         socket
         |> assign(:selected_student_ids, next_selected_student_ids)
         |> assign(:selected_students_data, selected_students_data)
         |> assign(:selected_emails, selected_student_emails(selected_students_data))
         |> assign(:show_email_modal, false)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("edit_threshold_definitions", _params, socket) do
    # TODO: wire threshold customization entrypoint when MER-5256 lands.
    {:noreply, socket}
  end

  defp build_chart_spec(buckets, selected_bucket_id) do
    # Phase 1 intentionally ships a minimal chart spec for renderer and interaction
    # validation. Final visual fidelity is deferred to the follow-up UI slice.
    ordered_buckets =
      Enum.sort_by(buckets, fn bucket ->
        Enum.find_index(@chart_bucket_order, &(&1 == bucket.id)) || length(@chart_bucket_order)
      end)

    chart_buckets = Enum.filter(ordered_buckets, &(&1.pct > 0.0))

    {values, _current_angle} =
      Enum.map_reduce(chart_buckets, 0.0, fn bucket, current_angle ->
        arc_angle = bucket.pct * 2 * :math.pi()

        value = %{
          bucket_id: bucket.id,
          bucket_order: Enum.find_index(@chart_bucket_order, &(&1 == bucket.id)) || 999,
          label: bucket.label,
          count: bucket.count,
          pct: Float.round(bucket.pct * 100.0, 1),
          selected: bucket.id == selected_bucket_id,
          theta_start: current_angle,
          theta_end: current_angle + arc_angle,
          selected_theta_start: current_angle,
          selected_theta_end: current_angle + arc_angle
        }

        {value, current_angle + arc_angle}
      end)

    %{
      "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
      "background" => "transparent",
      "width" => 240,
      "height" => 360,
      "data" => %{"values" => values},
      "view" => %{"stroke" => nil},
      "encoding" => %{
        "theta" => %{"field" => "theta_end", "type" => "quantitative", "stack" => nil},
        "theta2" => %{"field" => "theta_start"},
        "color" => %{
          "field" => "bucket_id",
          "type" => "nominal",
          "legend" => nil,
          "scale" => %{
            "domain" => @chart_bucket_order,
            "range" =>
              Enum.map(@chart_bucket_order, fn bucket_id ->
                bucket_id
                |> bucket_style()
                |> get_in([:chart, :light])
              end)
          }
        },
        "tooltip" => [
          %{"field" => "label", "type" => "nominal", "title" => "Bucket"},
          %{"field" => "count", "type" => "quantitative", "title" => "Students"},
          %{"field" => "pct", "type" => "quantitative", "title" => "Percent"}
        ]
      },
      "layer" => [
        %{
          "mark" => %{
            "type" => "arc",
            "innerRadius" => 58,
            "outerRadius" => 150,
            "strokeJoin" => "round"
          },
          "encoding" => %{
            "opacity" => %{
              "condition" => %{"test" => "datum.selected", "value" => 1},
              "value" => 0.45
            },
            "stroke" => %{"value" => @chart_theme_styles.separator.light},
            "strokeWidth" => %{"value" => 4}
          }
        },
        %{
          "transform" => [%{"filter" => "datum.selected"}],
          "mark" => %{
            "type" => "arc",
            "innerRadius" => 63,
            "outerRadius" => 145,
            "strokeJoin" => "round"
          },
          "encoding" => %{
            "theta" => %{
              "field" => "selected_theta_end",
              "type" => "quantitative",
              "stack" => nil
            },
            "theta2" => %{"field" => "selected_theta_start"},
            "opacity" => %{"value" => 1},
            "stroke" => %{"value" => @chart_theme_styles.border_active.light},
            "strokeWidth" => %{"value" => 6}
          }
        }
      ]
    }
  end

  defp projection_ready?(projection) do
    is_map(projection) and Map.has_key?(projection, :buckets) and
      Map.has_key?(projection, :has_activity_data?)
  end

  defp no_activity?(projection), do: Map.get(projection, :has_activity_data?) == false

  defp bucket_title(nil), do: "Student list"
  defp bucket_title(bucket), do: bucket.label

  defp bucket_student_count(nil), do: 0
  defp bucket_student_count(bucket), do: bucket.count

  defp bucket_total_students(projection), do: get_in(projection, [:totals, :total_students]) || 0

  defp bucket_threshold_rows("struggling") do
    [
      %{label: "Progress:", chips: ["< 40%", "> 80%"]},
      %{label: "Proficiency:", chips: ["< 40%"]}
    ]
  end

  defp bucket_threshold_rows("on_track") do
    [
      %{label: "Progress:", chips: ["40% - 80%"]},
      %{label: "Proficiency:", chips: ["40% - 80%"]}
    ]
  end

  defp bucket_threshold_rows("excelling") do
    [
      %{label: "Progress:", chips: ["≥ 60%"]},
      %{label: "Proficiency:", chips: ["≥ 80%"]}
    ]
  end

  defp bucket_threshold_rows("not_enough_information") do
    [
      %{label: "Progress:", chips: ["N/A"]},
      %{label: "Proficiency:", chips: ["N/A"]}
    ]
  end

  defp bucket_threshold_rows(_), do: []

  defp bucket_threshold_chip_class("struggling"),
    do: "bg-Fill-Accent-fill-accent-orange text-Text-text-accent-orange"

  defp bucket_threshold_chip_class("on_track"),
    do: "bg-Fill-Accent-fill-accent-teal text-Text-text-accent-teal"

  defp bucket_threshold_chip_class("excelling"),
    do: "bg-Fill-Accent-fill-accent-purple text-Text-text-accent-purple"

  defp bucket_threshold_chip_class("not_enough_information"),
    do: "bg-Fill-Accent-fill-accent-grey text-Text-text-high"

  defp bucket_threshold_chip_class(_), do: "bg-Fill-fill-transparent text-Text-text-high"

  defp activity_count(nil, _status), do: 0
  defp activity_count(bucket, :active), do: Map.get(bucket, :active_count, 0)
  defp activity_count(bucket, :inactive), do: Map.get(bucket, :inactive_count, 0)

  defp graph_key_label(bucket) do
    case bucket.id do
      "on_track" -> "On Track"
      "not_enough_information" -> "N/A"
      _ -> bucket.label
    end
  end

  defp graph_key_label_width_class(bucket_id)
       when bucket_id in ["struggling", "on_track", "excelling"],
       do: "justify-start"

  defp graph_key_label_width_class(_), do: "justify-start"

  defp graph_key_aria_label(bucket, count, pct, selected) do
    state = if selected, do: ", selected", else: ""
    "#{graph_key_label(bucket)}, #{count} students, #{pct} percent#{state}"
  end

  defp filter_button_label(label, count, selected, with_dot) do
    status =
      case {with_dot, label} do
        {true, "Inactive"} -> ", no activity in the past 7 days"
        _ -> ""
      end

    selected_state = if selected, do: ", selected", else: ""
    "#{label}, #{count} students#{status}#{selected_state}"
  end

  defp inactive_tooltip("Inactive"), do: "Inactive = no activity in the past 7 days"
  defp inactive_tooltip(_), do: nil

  defp bucket_style(bucket_id),
    do: Map.get(@bucket_styles, bucket_id, @bucket_styles["not_enough_information"])

  defp bucket_accent_class(bucket_id) do
    bucket_id
    |> bucket_style()
    |> Map.get(:accent_class, "bg-Fill-Accent-fill-accent-grey")
  end

  defp chart_colors do
    Enum.into(@bucket_styles, %{}, fn {bucket_id, style_map} ->
      {bucket_id, style_map.chart}
    end)
  end

  defp active_selected?(filter), do: filter in [:all, :active]
  defp inactive_selected?(filter), do: filter in [:all, :inactive]

  defp selected?(student, selected_student_ids), do: student.id in selected_student_ids

  defp normalize_selected_student_ids(nil), do: []

  defp normalize_selected_student_ids(selected_student_ids) when is_list(selected_student_ids),
    do: selected_student_ids

  defp selected_students_data(student_lookup, selected_student_ids) do
    selected_student_ids
    |> Enum.map(&Map.get(student_lookup, &1))
    |> Enum.reject(&is_nil/1)
  end

  defp selected_student_emails(selected_students_data) do
    selected_students_data
    |> Enum.map(& &1.email)
    |> Oli.Utils.normalize_and_join_strings(", ", unique: true)
  end

  defp student_lookup(projection) do
    projection
    |> Map.get(:buckets, [])
    |> Enum.flat_map(&Map.get(&1, :students, []))
    |> Enum.reduce(%{}, fn student, acc ->
      Map.put_new(acc, student.id, student)
    end)
  end

  defp current_visible_students(projection, tile_state) do
    projection
    |> selected_bucket_id(tile_state)
    |> then(fn bucket_id ->
      Enum.find(Map.get(projection, :buckets, []), &(&1.id == bucket_id))
    end)
    |> filter_students(
      Map.get(tile_state, :selected_activity_filter, :all),
      Map.get(tile_state, :search_term, "")
    )
    |> Enum.take(Map.get(tile_state, :visible_count, 20))
  end

  defp student_profile_path(section_slug, student) do
    ~p"/sections/#{section_slug}/student_dashboard/#{student.id}/content"
  end

  defp projection_signature(projection, tile_state) do
    %{
      dataset_signature: dataset_signature(projection),
      bucket_id: selected_bucket_id(projection, tile_state),
      selected_filter: Map.get(tile_state, :selected_activity_filter, :all),
      search_term: Map.get(tile_state, :search_term, ""),
      bucket_counts:
        projection
        |> Map.get(:buckets, [])
        |> Enum.map(fn bucket ->
          {bucket.id, bucket.count, bucket.active_count, bucket.inactive_count}
        end)
    }
  end

  defp dataset_signature(projection) do
    projection
    |> Map.get(:buckets, [])
    |> Enum.map(fn bucket ->
      {bucket.id, Enum.map(Map.get(bucket, :students, []), & &1.id)}
    end)
  end

  defp filter_patch_updates(:all, :active), do: %{"filter" => "inactive", "page" => 1}
  defp filter_patch_updates(:all, :inactive), do: %{"filter" => "active", "page" => 1}
  defp filter_patch_updates(:active, :inactive), do: %{"filter" => nil, "page" => 1}
  defp filter_patch_updates(:inactive, :active), do: %{"filter" => nil, "page" => 1}
  defp filter_patch_updates(:active, :active), do: %{"filter" => "active", "page" => 1}
  defp filter_patch_updates(:inactive, :inactive), do: %{"filter" => "inactive", "page" => 1}
  defp filter_patch_updates(_, clicked), do: filter_patch_updates(:all, clicked)

  defp tile_patch_path(assigns, updates) do
    params =
      assigns
      |> Map.get(:params, %{})
      |> Enum.into(%{}, fn {key, value} -> {to_string(key), value} end)

    tile_support =
      params
      |> Map.get("tile_support", %{})
      |> Enum.into(%{}, fn {key, value} -> {to_string(key), value} end)
      |> Map.merge(updates)
      |> Enum.reject(fn
        {"page", 1} -> true
        {"page", "1"} -> true
        {"filter", "all"} -> true
        {"q", ""} -> true
        {_key, nil} -> true
        _ -> false
      end)
      |> Map.new()

    params =
      if map_size(tile_support) == 0 do
        Map.delete(params, "tile_support")
      else
        Map.put(params, "tile_support", tile_support)
      end

    OliWeb.Delivery.InstructorDashboard.IntelligentDashboardTab.path_for_section(
      assigns.section_slug,
      assigns.dashboard_scope,
      params
    )
  end
end
