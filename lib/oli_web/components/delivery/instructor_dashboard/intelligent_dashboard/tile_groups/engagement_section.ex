defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.TileGroups.EngagementSection do
  @moduledoc """
  Engagement tile-group composition for Intelligent Dashboard.

  This module wraps the Engagement tiles with the shared
  `DashboardSectionChrome` and derives the section layout from the
  number of visible tiles.

  Group ownership:
  - `ProgressTile`
  - `StudentSupportTile`
  """

  use OliWeb, :html

  alias OliWeb.Components.Delivery.InstructorDashboard.DashboardSectionChrome
  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.ProgressTile

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.StudentSupportTile

  attr :expanded, :boolean, default: true
  attr :target, :any, default: nil
  attr :toggle_event, :string, default: "dashboard_section_toggled"
  attr :reorder_event, :string, default: "dashboard_sections_reordered"
  attr :show_move_handle, :boolean, default: true
  attr :progress_projection, :map, default: %{}
  attr :progress_tile_state, :map, default: %{}
  attr :student_support_projection, :map, default: %{}
  attr :student_support_tile_state, :map, default: %{}
  attr :show_student_support_parameters_modal, :boolean, default: false
  attr :student_support_parameters_draft, :map, default: nil
  attr :student_support_parameters_error, :atom, default: nil
  attr :params, :map, default: %{}
  attr :section_slug, :string, required: true
  attr :section_title, :string, default: nil
  attr :instructor_email, :string, default: nil
  attr :instructor_name, :string, default: nil
  attr :dashboard_scope, :string, default: "course"
  attr :show_progress_tile, :boolean, default: true
  attr :show_student_support_tile, :boolean, default: true
  attr :tile_split, :integer, default: 43

  def section(assigns) do
    tile_count = visible_tile_count(assigns)

    assigns =
      assigns
      |> assign(:tile_count, tile_count)
      |> assign(:show_resize_handle, tile_count == 2)

    ~H"""
    <DashboardSectionChrome.section
      id="learning-dashboard-engagement-group"
      section_id="engagement"
      title="Engagement"
      expanded={@expanded}
      target={@target}
      toggle_event={@toggle_event}
      reorder_event={@reorder_event}
      show_move_handle={@show_move_handle}
    >
      <div
        id="learning-dashboard-engagement-group-tiles"
        phx-hook={if @show_resize_handle, do: "DashboardTileGroupResize"}
        data-dashboard-section-id="engagement"
        data-dashboard-section-split={@tile_split}
        data-section-layout={if @tile_count == 1, do: "single", else: "multi"}
        class={[
          "relative grid grid-cols-1 gap-4",
          @show_resize_handle &&
            "xl:gap-0 xl:grid-cols-[minmax(0,var(--dashboard-section-split))_minmax(0,calc(100%_-_var(--dashboard-section-split)))]"
        ]}
        style={if @show_resize_handle, do: "--dashboard-section-split: #{@tile_split}%;", else: nil}
      >
        <div
          :if={@show_progress_tile}
          data-dashboard-section-tile-pane
          data-dashboard-section-tile-pane-index="0"
          class={["relative overflow-visible min-w-0", @show_resize_handle && "xl:pr-2"]}
        >
          <.live_component
            module={ProgressTile}
            id="progress_tile"
            projection={@progress_projection}
            tile_state={@progress_tile_state}
            params={@params}
            section_slug={@section_slug}
            dashboard_scope={@dashboard_scope}
          />
        </div>
        <div
          :if={@show_student_support_tile}
          data-dashboard-section-tile-pane
          data-dashboard-section-tile-pane-index="1"
          class={["relative overflow-visible min-w-0", @show_resize_handle && "xl:pl-2"]}
        >
          <.live_component
            module={StudentSupportTile}
            id="student_support_tile"
            projection={@student_support_projection}
            tile_state={@student_support_tile_state}
            show_student_support_parameters_modal={@show_student_support_parameters_modal}
            student_support_parameters_draft={@student_support_parameters_draft}
            student_support_parameters_error={@student_support_parameters_error}
            params={@params}
            section_slug={@section_slug}
            section_title={@section_title}
            instructor_email={@instructor_email}
            instructor_name={@instructor_name}
            dashboard_scope={@dashboard_scope}
          />
        </div>

        <button
          :if={@show_resize_handle}
          type="button"
          class="absolute z-20 w-3 -translate-x-1/2 -translate-y-1/2 cursor-col-resize bg-transparent"
          aria-label="Resize Progress tile"
          data-dashboard-section-resize-handle
          data-pane-index="0"
        />

        <button
          :if={@show_resize_handle}
          type="button"
          class="absolute z-20 w-3 -translate-x-1/2 -translate-y-1/2 cursor-col-resize bg-transparent"
          aria-label="Resize Student Support tile"
          data-dashboard-section-resize-handle
          data-pane-index="1"
        />
      </div>
    </DashboardSectionChrome.section>
    """
  end

  defp visible_tile_count(assigns) do
    Enum.count([assigns.show_progress_tile, assigns.show_student_support_tile], & &1)
  end
end
