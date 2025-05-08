defmodule OliWeb.Delivery.Student.AssignmentsLive do
  use OliWeb, :live_view

  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Delivery.{Certificates, Metrics, Settings}
  alias OliWeb.Common.{FormatDateTime, SessionContext}
  alias OliWeb.Components.Delivery.Utils, as: DeliveryUtils
  alias OliWeb.Delivery.Student.Utils
  alias OliWeb.Icons

  # this is an optimization to reduce the memory footprint of the liveview process
  @required_keys_per_assign %{
    section:
      {[
         :id,
         :slug,
         :customizations,
         :title,
         :brand,
         :lti_1p3_deployment,
         :contains_discussions,
         :contains_explorations,
         :contains_deliberate_practice,
         :open_and_free
       ], %Section{}},
    current_user: {[:id, :name, :email, :sub], %User{}}
  }

  def mount(_params, _session, socket) do
    %{section: section, current_user: %{id: current_user_id}} = socket.assigns

    certificate =
      if section.certificate_enabled, do: Certificates.get_certificate_by(section_id: section.id)

    send(self(), :gc)

    {:ok,
     assign(socket,
       active_tab: :assignments,
       assignments: get_assignments(section, current_user_id),
       certificate: certificate,
       filter: :all,
       filter_expanded: false
     )
     |> slim_assigns()}
  end

  defp slim_assigns(socket) do
    Enum.reduce(@required_keys_per_assign, socket, fn {assign_name, {required_keys, struct}},
                                                      socket ->
      assign(
        socket,
        assign_name,
        Map.merge(
          struct,
          Map.filter(socket.assigns[assign_name], fn {k, _v} -> k in required_keys end)
        )
      )
    end)
  end

  def handle_info(:gc, socket) do
    # manually garbage collect to reduce memory usage after mount/3
    :erlang.garbage_collect(socket.transport_pid)
    :erlang.garbage_collect(self())
    {:noreply, socket}
  end

  def handle_event("toggle_filter_open", _, socket) do
    {:noreply, assign(socket, filter_expanded: !socket.assigns.filter_expanded)}
  end

  def handle_event("collapse_select", _, socket) do
    {:noreply, assign(socket, filter_expanded: false)}
  end

  def handle_event("select_filter", params, socket) do
    case params["filter"] do
      "all" -> {:noreply, assign(socket, filter: :all, filter_expanded: false)}
      "required" -> {:noreply, assign(socket, filter: :required, filter_expanded: false)}
      _ -> socket
    end
  end

  def render(assigns) do
    ~H"""
    <.top_hero_banner />
    <div class="flex flex-col justify-center py-9 px-20 w-full gap-12">
      <.certificate_requirements certificate={@certificate} />
      <.filter_dropdown :if={@certificate} filter={@filter} filter_expanded={@filter_expanded} />

      <.assignments_agenda
        has_scheduled_resources?={@has_scheduled_resources?}
        assignments={@assignments}
        ctx={@ctx}
        section_slug={@section.slug}
        certificate={@certificate}
        filter={@filter}
      />
    </div>
    """
  end

  def top_hero_banner(assigns) do
    ~H"""
    <div
      role="hero banner"
      class="w-full bg-cover bg-center bg-no-repeat h-[160px] md:h-[247px]"
      style="background-image: url('/images/gradients/assignments-bg.png');"
    >
      <div class="h-[160px] md:h-[247px] bg-gradient-to-r from-[#e4e4ea] dark:from-[#0a0b11] to-transparent">
        <h1 class="py-12 md:py-20 pl-[76px] text-4xl md:text-6xl font-normal tracking-tight dark:text-white">
          Assignments
        </h1>
      </div>
    </div>
    """
  end

  attr :certificate, :map, default: nil

  def certificate_requirements(%{certificate: nil} = assigns) do
    ~H"""
    """
  end

  def certificate_requirements(assigns) do
    ~H"""
    <div
      id="certificate_requirements"
      class="w-full h-[81px] justify-center items-center inline-flex mb-20 sm:mb-0"
    >
      <div class="grow shrink basis-0 self-stretch flex-col justify-start items-start gap-[5px] inline-flex">
        <div class="flex-col justify-center items-start gap-[8px] flex">
          <div class="w-full h-fit dark:text-[#e6e9f2]">
            <span class="font-bold">
              This is a Certificate Course.
            </span>
            <span class="dark:text-[#e6e9f2] font-normal">
              Complete all required assignments (
            </span>
            <span class="text-[#ff8787] text-xl font-normal">*</span>
            <span class="dark:text-[#e6e9f2] font-normal">
              ) and follow these scoring guidelines:
            </span>
          </div>
          <div class="w-full grow shrink basis-0">
            <div class="w-full h-fit">
              <span class="text-sm font-bold">
                Certificate of Completion:
              </span>
              <span class="text-sm font-normal"> Earn </span>
              <span class="text-[#2db767] dark:text-[#39e581] text-sm font-bold">
                <%= format_percentage(@certificate.min_percentage_for_completion) %>
              </span>
              <span class="text-sm font-normal">or above on all required assignments</span>
            </div>
            <div class="w-full h-fit">
              <span class="text-sm font-bold">
                Certificate with Distinction:
              </span>
              <span class="text-sm font-bold"></span><span class="text-sm font-normal">Earn</span>
              <span class="text-[#2db767] dark:text-[#39e581] text-sm font-bold">
                <%= format_percentage(@certificate.min_percentage_for_distinction) %>
              </span>
              <span class="text-sm font-normal"></span><span class="text-sm font-normal">or above on all required assignments</span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :assignments, :list, required: true
  attr :ctx, SessionContext, required: true
  attr :section_slug, :string, required: true
  attr :certificate, :map, required: true
  attr :filter, :atom, required: true
  attr :has_scheduled_resources?, :boolean, required: true

  def assignments_agenda(assigns) do
    ~H"""
    <div class="w-full px-2 bg-white dark:bg-[#1b191f]/50 rounded-xl border border-[#ced1d9] dark:border-[#2a282d] flex-col justify-start items-start inline-flex">
      <div
        role="assignments header"
        class="w-full h-11 py-3 border-b border-[#ced1d9] dark:border-[#3a3740] justify-between items-center inline-flex text-[#757682] dark:text-[#bab8bf] text-sm font-medium leading-none"
      >
        <div class="justify-end items-center gap-2 flex">
          <div class="w-5 h-5 relative"><Icons.check /></div>
          <span>
            <%= completed_assignments_count(@assignments, @certificate, @filter) %> of <%= total_assignments_count(
              @assignments,
              @certificate,
              @filter
            ) %> Assignments
          </span>
        </div>
        <DeliveryUtils.toggle_visibility_button
          :if={@assignments != []}
          target_selector={~s{div[role="assignment detail"][data-completed="true"]}}
        />
      </div>
      <div role="assignments details" class="mt-12 px-5 pb-5 flex flex-col gap-12 w-full">
        <.assignment
          :for={assignment <- @assignments}
          :if={@assignments != []}
          filter={@filter}
          assignment={assignment}
          ctx={@ctx}
          target={
            Utils.lesson_live_path(@section_slug, assignment.slug,
              request_path: ~p"/sections/#{@section_slug}/assignments"
            )
          }
          required={assignment_required_for_certificate(assignment, @certificate)}
          has_scheduled_resources?={@has_scheduled_resources?}
        />
        <span :if={@assignments == []}>There are no assignments</span>
      </div>
    </div>
    """
  end

  defp total_assignments_count(assignments, certificate, filter)
       when is_nil(certificate) or filter == :all,
       do: Enum.count(assignments)

  defp total_assignments_count(assignments, certificate, :required),
    do: Enum.count(assignments, &assignment_required_for_certificate(&1, certificate))

  defp completed_assignments_count(assignments, certificate, filter)
       when is_nil(certificate) or filter == :all,
       do: Enum.count(assignments, &(!is_nil(&1.raw_avg_score)))

  defp completed_assignments_count(assignments, certificate, :required),
    do:
      Enum.count(
        assignments,
        &(!is_nil(&1.raw_avg_score) and assignment_required_for_certificate(&1, certificate))
      )

  attr :assignment, :map, required: true
  attr :ctx, SessionContext, required: true
  attr :target, :string, required: true, doc: "The target URL for the assignment"

  attr :required, :boolean,
    default: false,
    doc: "Whether the assignment is required for the certificate"

  attr :filter, :atom, required: true
  attr :has_scheduled_resources?, :boolean, required: true

  def assignment(assigns) do
    ~H"""
    <div
      :if={@filter == :all or (@filter == :required and @required)}
      role="assignment detail"
      id={"assignment_#{@assignment.id}"}
      data-completed={"#{!is_nil(@assignment.raw_avg_score)}"}
      class="h-12 flex"
    >
      <div role="page icon" class="w-6 h-6 flex justify-center items-center">
        <.page_icon
          purpose={@assignment.purpose}
          completed={!is_nil(@assignment.raw_avg_score)}
          required={@required}
        />
      </div>
      <div class="ml-6 mt-0.5 h-6 w-10 flex items-center text-left text-[#757682] dark:text-[#eeebf5]/75 text-sm font-semibold leading-none">
        <%= @assignment.numbering_index %>
      </div>
      <div class="h-12 flex flex-col justify-between mr-6 flex-1 min-w-0">
        <.link
          navigate={@target}
          class="h-6 mt-0.5 text-[#353740] dark:text-[#eeebf5] text-base font-semibold leading-normal whitespace-nowrap truncate"
        >
          <%= @assignment.title %>
        </.link>
        <span
          :if={@has_scheduled_resources?}
          role="assignment schedule details"
          class="text-[#757682] dark:text-[#eeebf5]/75 text-xs font-semibold leading-3 whitespace-nowrap truncate"
        >
          <%= Utils.label_for_scheduling_type(@assignment.scheduling_type) %> <%= FormatDateTime.to_formatted_datetime(
            @assignment.end_date,
            @ctx,
            "{WDshort} {Mshort} {D}, {YYYY}"
          ) %>
        </span>
      </div>
      <div :if={@assignment.raw_avg_score} class="ml-auto h-12 flex flex-col justify-between">
        <span class="h-6 ml-auto text-[#757682] dark:text-[#eeebf5]/75 text-xs font-semibold leading-3 whitespace-nowrap">
          Attempt <%= @assignment.attempts %> of <%= max_attempts(@assignment.max_attempts) %>
        </span>
        <div class="flex ml-auto gap-1.5 text-[#218358] dark:text-[#39e581]">
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
        id: assignment.resource_id,
        title: assignment.title,
        numbering_index: assignment.numbering_index,
        scheduling_type: effective_settings.scheduling_type,
        end_date: effective_settings.end_date,
        purpose: assignment.purpose,
        progress: progress_per_page_id[assignment.resource_id],
        raw_avg_score: raw_avg_score_per_page_id[assignment.resource_id],
        max_attempts: effective_settings.max_attempts,
        attempts: user_resource_attempt_counts[assignment.resource_id] || 0,
        slug: assignment.revision_slug
      }
    end)
  end

  defp max_attempts(0), do: "∞"
  defp max_attempts(max_attempts), do: max_attempts

  attr :completed, :boolean, required: true
  attr :purpose, :atom, required: true
  attr :required, :boolean, required: true

  defp page_icon(assigns) do
    ~H"""
    <%= cond do %>
      <% @purpose == :application -> %>
        <span class="text-[#9a40a8] dark:text-[#ebaaf2]"><Icons.world /></span>
      <% @completed -> %>
        <Icons.square_checked class="fill-[#218358] dark:fill-[#39e581]" />
      <% @required -> %>
        <Icons.asterisk />
      <% true -> %>
        <Icons.flag fill_class="fill-[#fa8d3e] dark:fill-[#ff9040]" />
    <% end %>
    """
  end

  attr :filter, :atom, required: true
  attr :filter_expanded, :boolean, default: false

  defp filter_dropdown(assigns) do
    ~H"""
    <div class="flex relative justify-end mb-6" phx-click-away="collapse_select">
      <button
        class={[
          "h-6 px-2 py-[3px] bg-black/10 dark:bg-white/10 rounded-xl justify-start items-center gap-2 overflow-hidden hover:cursor-pointer hover:bg-black/20 hover:dark:bg-white/20",
          if(@filter == :all, do: "w-[180px]", else: "w-[210px]")
        ]}
        phx-click="toggle_filter_open"
      >
        <div class="pl-1 justify-start items-center gap-2.5 flex">
          <%= case @filter do %>
            <% :all -> %>
              <Icons.transparent_flag class="dark:stroke-white" />
              <div class="text-[13px] font-semibold">
                All Assignments
              </div>
            <% :required -> %>
              <Icons.asterisk class="dark:fill-white" />
              <div class="text-[13px] font-semibold">
                Required Assignments
              </div>
          <% end %>

          <Icons.chevron_down
            width="16"
            height="16"
            class={if @filter_expanded, do: "-rotate-180 ml-auto", else: "ml-auto"}
          />
        </div>
      </button>
      <div
        :if={@filter_expanded}
        class={[
          "h-13 absolute top-8 flex flex-col rounded-lg border border-black/20 dark:border-[#3B3740] justify-start items-center overflow-hidden divide-y divide-black/20 dark:divide-white/20",
          if(@filter == :all, do: "w-[180px]", else: "w-[210px]")
        ]}
      >
        <% opts = if @filter == :all, do: [:required, :all], else: [:all, :required] %>
        <.filter_option :for={opt <- opts} option={opt} />
      </div>
    </div>
    """
  end

  def filter_option(%{option: :all} = assigns) do
    ~H"""
    <button
      id="select_all_option"
      class="w-full h-6 p-3 justify-start items-center gap-2.5 flex hover:cursor-pointer bg-black/10 dark:bg-white/10 hover:bg-black/20 hover:dark:bg-white/20"
      phx-click="select_filter"
      phx-value-filter="all"
    >
      <Icons.transparent_flag class="dark:stroke-white" />
      <div class="text-[13px] font-semibold">
        All
      </div>
    </button>
    """
  end

  def filter_option(%{option: :required} = assigns) do
    ~H"""
    <button
      id="select_required_option"
      class="w-full h-6 p-3 justify-start items-center gap-2.5 flex hover:cursor-pointer bg-black/10 dark:bg-white/10 hover:bg-black/20 hover:dark:bg-white/20"
      phx-click="select_filter"
      phx-value-filter="required"
    >
      <Icons.asterisk class="dark:fill-white" />
      <div class="text-[13px] font-semibold pl-1.5">
        Required
      </div>
    </button>
    """
  end

  defp format_percentage(percentage) do
    "#{trunc(percentage)}%"
  end

  defp assignment_required_for_certificate(_assignment, nil), do: false

  defp assignment_required_for_certificate(assignment, certificate),
    do:
      certificate.assessments_apply_to == :all or
        assignment.id in certificate.custom_assessments
end
