defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.TileGroups.ContentSection do
  @moduledoc """
  Content tile-group composition for Intelligent Dashboard.

  This module wraps the Content tiles with the shared
  `DashboardSectionChrome` and derives the section layout from the
  number of visible tiles.

  Group ownership:
  - `ChallengingObjectivesTile`
  - `AssessmentsTile`
  """

  use OliWeb, :html

  alias OliWeb.Components.Delivery.InstructorDashboard.DashboardSectionChrome
  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.AssessmentsTile

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.{
    ChallengingObjectivesTile
  }

  attr :expanded, :boolean, default: true
  attr :target, :any, default: nil
  attr :toggle_event, :string, default: "dashboard_section_toggled"
  attr :reorder_event, :string, default: "dashboard_sections_reordered"
  attr :show_move_handle, :boolean, default: true
  attr :objectives_projection, :map, default: nil
  attr :objectives_projection_status, :map, default: %{status: :loading}
  attr :objectives_projection_identity, :string, default: "loading"
  attr :section_slug, :string, required: true
  attr :assessments_status, :string, default: "Waiting for scoped data"
  attr :assessments_projection, :map, default: %{}
  attr :assessments_tile_state, :map, default: %{}
  attr :ctx, :map, default: nil
  attr :section_id, :integer, default: nil
  attr :section_title, :string, default: nil
  attr :instructor_email, :string, default: nil
  attr :instructor_name, :string, default: nil
  attr :show_objectives_tile, :boolean, default: true
  attr :show_assessments_tile, :boolean, default: true
  attr :tile_split, :integer, default: 43

  def section(assigns) do
    assigns =
      assigns
      |> assign(:tile_count, visible_tile_count(assigns))
      |> assign(:show_resize_handle, visible_tile_count(assigns) == 2)

    ~H"""
    <DashboardSectionChrome.section
      id="learning-dashboard-content-group"
      section_id="content"
      title="Content"
      expanded={@expanded}
      target={@target}
      toggle_event={@toggle_event}
      reorder_event={@reorder_event}
      show_move_handle={@show_move_handle}
    >
      <div
        id="learning-dashboard-content-group-tiles"
        phx-hook={if @show_resize_handle, do: "DashboardTileGroupResize"}
        data-dashboard-section-id="content"
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
          :if={@show_objectives_tile}
          data-dashboard-section-tile-pane
          data-dashboard-section-tile-pane-index="0"
          class={["relative z-10 overflow-visible min-w-0", @show_resize_handle && "xl:pr-2"]}
        >
          <ChallengingObjectivesTile.tile
            projection={@objectives_projection}
            projection_status={@objectives_projection_status}
            projection_identity={@objectives_projection_identity}
            section_slug={@section_slug}
          />
        </div>
        <div
          :if={@show_assessments_tile}
          data-dashboard-section-tile-pane
          data-dashboard-section-tile-pane-index="1"
          class={["relative z-10 overflow-visible min-w-0", @show_resize_handle && "xl:pl-2"]}
        >
          <.live_component
            module={AssessmentsTile}
            id="assessments_tile"
            projection={@assessments_projection}
            expanded_assessment_id={Map.get(@assessments_tile_state, :expanded_assessment_id)}
            status={@assessments_status}
            ctx={@ctx}
            section_slug={@section_slug}
            section_id={@section_id}
            section_title={@section_title}
            instructor_email={@instructor_email}
            instructor_name={@instructor_name}
          />
        </div>

        <button
          :if={@show_resize_handle}
          type="button"
          class="absolute z-20 w-3 -translate-x-1/2 -translate-y-1/2 cursor-col-resize bg-transparent"
          aria-label="Resize Challenging Objectives tile"
          data-dashboard-section-resize-handle
          data-pane-index="0"
        />

        <button
          :if={@show_resize_handle}
          type="button"
          class="absolute z-20 w-3 -translate-x-1/2 -translate-y-1/2 cursor-col-resize bg-transparent"
          aria-label="Resize Assessments tile"
          data-dashboard-section-resize-handle
          data-pane-index="1"
        />
      </div>
    </DashboardSectionChrome.section>
    """
  end

  defp visible_tile_count(assigns) do
    Enum.count([assigns.show_objectives_tile, assigns.show_assessments_tile], & &1)
  end
end
