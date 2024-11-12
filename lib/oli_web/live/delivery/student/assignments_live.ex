defmodule OliWeb.Delivery.Student.AssignmentsLive do
  use OliWeb, :live_view

  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Delivery.{Metrics, Settings}
  alias OliWeb.Common.{FormatDateTime, SessionContext}
  alias OliWeb.Components.Delivery.Utils, as: DeliveryUtils
  alias OliWeb.Delivery.Student.Utils
  alias OliWeb.Icons

  def mount(_params, _session, socket) do
    %{section: section, current_user: %{id: current_user_id}} = socket.assigns

    {:ok,
     assign(socket,
       active_tab: :assignments,
       assignments: get_assignments(section, current_user_id)
     )}
  end

  def render(assigns) do
    ~H"""
    <.top_hero_banner />
    <div class="flex justify-center py-9 px-20 w-full">
      <.assignments_agenda assignments={@assignments} ctx={@ctx} />
    </div>
    """
  end

  def top_hero_banner(assigns) do
    ~H"""
    <div
      role="hero banner"
      class="w-full bg-cover bg-center bg-no-repeat h-[247px]"
      style="background-image: url('/images/gradients/assignments-bg.png');"
    >
      <div class="h-[247px] bg-gradient-to-r from-[#e4e4ea] dark:from-[#0a0b11] to-transparent">
        <h1 class="py-20 pl-[76px] text-4xl md:text-6xl font-normal tracking-tight dark:text-white">
          Assignments
        </h1>
      </div>
    </div>
    """
  end

  attr :assignments, :list, required: true
  attr :ctx, SessionContext, required: true

  def assignments_agenda(assigns) do
    ~H"""
    <div class="w-full px-2 bg-[#1b191f]/50 rounded-xl border border-[#2a282d] flex-col justify-start items-start inline-flex">
      <div
        role="assignments header"
        class="w-full h-11 py-3 border-b border-[#3a3740] justify-between items-center inline-flex text-[#bab8bf] text-sm font-medium leading-none"
      >
        <div class="justify-end items-center gap-2 flex">
          <div class="w-5 h-5 relative"><Icons.check /></div>
          <span>
            <%= Enum.count(@assignments, &(!is_nil(&1.raw_avg_score))) %> of <%= Enum.count(
              @assignments
            ) %> Assignments
          </span>
        </div>
        <DeliveryUtils.toggle_visibility_button target_selector={
          ~s{div[role="assignment detail"][data-completed="true"]}
        } />
      </div>
      <div role="assignments details" class="mt-12 px-5 pb-5 flex flex-col gap-12 w-full">
        <.assignment :for={assignment <- @assignments} assignment={assignment} ctx={@ctx} />
      </div>
    </div>
    """
  end

  attr :assignment, :map, required: true
  attr :ctx, SessionContext, required: true

  def assignment(assigns) do
    ~H"""
    <div
      role="assignment detail"
      data-completed={"#{!is_nil(@assignment.raw_avg_score)}"}
      class="h-12 flex"
    >
      <div class="w-6 h-6 flex justify-center items-center">
        <Icons.flag />
      </div>
      <div class="ml-2 mt-0.5 h-6 w-10 flex items-center text-left text-[#eeebf5]/75 text-sm font-semibold leading-none">
        <%= @assignment.numbering_index %>
      </div>
      <div class="h-12 flex flex-col justify-between mr-6 flex-1 min-w-0">
        <div class="h-6 mt-0.5 text-[#eeebf5] text-base font-semibold leading-normal whitespace-nowrap truncate">
          <%= @assignment.title %>
        </div>
        <span class="text-[#eeebf5]/75 text-xs font-semibold leading-3 whitespace-nowrap truncate">
          <%= Utils.label_for_scheduling_type(@assignment.scheduling_type) %> <%= FormatDateTime.to_formatted_datetime(
            @assignment.end_date,
            @ctx,
            "{WDshort} {Mshort} {D}, {YYYY}"
          ) %>
        </span>
      </div>
      <div :if={@assignment.raw_avg_score} class="ml-auto h-12 flex flex-col justify-between">
        <span class="h-6 ml-auto text-[#eeebf5]/75 text-xs font-semibold leading-3 whitespace-nowrap">
          Attempt <%= @assignment.attempts %> of <%= max_attempts(@assignment.max_attempts) %>
        </span>
        <div class="flex ml-auto gap-1.5 text-[#39e581]">
          <div class="w-4 h-4"><Icons.star /></div>
          <span class="flex gap-1 text-base font-bold leading-none whitespace-nowrap">
            <%= Utils.parse_score(@assignment.raw_avg_score.score) %> / <%= Utils.parse_score(
              @assignment.raw_avg_score.out_of
            ) %>
          </span>
        </div>
      </div>
      <div :if={is_nil(@assignment.raw_avg_score)} class="ml-auto h-12 flex flex-col justify-between">
        <span class="h-6 ml-auto text-[#eeebf5]/75 text-xs font-semibold leading-3 whitespace-nowrap">
          --
        </span>
      </div>
    </div>
    """
  end

  _docp = """
  Returns a list of assignments by querying the section resources form the SectionResourceDepot
  and merging the results with the combined settings and metrics for the current user.

  Only required fields needed for render/1 are returned (to reduce memory usage).
  """

  defp get_assignments(section, current_user_id) do
    raw_assignments = SectionResourceDepot.graded_pages(section.id, hidden: false)
    resource_ids = Enum.map(raw_assignments, & &1.resource_id)

    combined_settings =
      Settings.get_combined_settings_for_all_resources(section.id, current_user_id, resource_ids)

    progress_per_page_id =
      Metrics.progress_across_for_pages(section.id, resource_ids, [current_user_id])

    raw_avg_score_per_page_id =
      Metrics.raw_avg_score_across_for_pages(section, resource_ids, [current_user_id])

    user_resource_attempt_counts =
      Metrics.get_all_user_resource_attempt_counts(section, current_user_id)

    Enum.map(raw_assignments, fn assignment ->
      effective_settings = Map.get(combined_settings, assignment.resource_id, %{})

      %{
        title: assignment.title,
        numbering_index: assignment.numbering_index,
        scheduling_type: effective_settings.scheduling_type,
        end_date: effective_settings.end_date,
        purpose: assignment.purpose,
        progress: progress_per_page_id[assignment.resource_id],
        raw_avg_score:
          raw_avg_score_per_page_id[assignment.resource_id] |> IO.inspect(label: "raw avg score"),
        max_attempts: effective_settings.max_attempts,
        attempts: user_resource_attempt_counts[assignment.resource_id] || 0
      }
    end)
  end

  defp max_attempts(0), do: "∞"
  defp max_attempts(max_attempts), do: max_attempts
end
