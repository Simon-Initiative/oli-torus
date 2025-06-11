defmodule OliWeb.Delivery.Student.IndexLive do
  use OliWeb, :live_view
  use Appsignal.Instrumentation.Decorators
  import OliWeb.Components.Delivery.Layouts

  alias Oli.Delivery.{Attempts, Certificates, Hierarchy, Metrics, Sections, Settings}
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Publishing.DeliveryResolver
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Components.Common
  alias OliWeb.Components.Delivery.Student
  alias OliWeb.Components.Modal
  alias OliWeb.Delivery.Student.Utils
  alias OliWeb.Delivery.Student.Home.Components.ScheduleComponent
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  @decorate transaction_event("IndexLive")
  def mount(_params, _session, socket) do
    if connected?(socket) do
      section = socket.assigns[:section]
      current_user_id = socket.assigns[:current_user].id
      certificate_enabled = section.certificate_enabled
      has_scheduled_resources? = socket.assigns[:has_scheduled_resources?]

      combined_settings =
        Appsignal.instrument("IndexLive: combined_settings", fn ->
          Settings.get_combined_settings_for_all_resources(section.id, current_user_id)
        end)

      nearest_upcoming_lesson =
        Appsignal.instrument("IndexLive: nearest_upcoming_lesson", fn ->
          section
          |> Sections.get_nearest_upcoming_lessons(current_user_id, 1,
            ignore_schedule: !has_scheduled_resources?
          )
          |> List.first()
        end)

      latest_assignments =
        Appsignal.instrument("IndexLive: latest_assignments", fn ->
          Sections.get_last_completed_or_started_assignments(section, current_user_id, 3)
        end)

      upcoming_assignments =
        Appsignal.instrument("IndexLive: upcoming_assignments", fn ->
          Sections.get_nearest_upcoming_lessons(section, current_user_id, 3,
            only_graded: true,
            ignore_schedule: !has_scheduled_resources?
          )
        end)

      page_ids = Enum.map(upcoming_assignments ++ latest_assignments, & &1.resource_id)
      containers_per_page = build_containers_per_page(section, page_ids)

      [last_open_and_unfinished_page, nearest_upcoming_lesson] =
        Appsignal.instrument("IndexLive: last_open_and_unfinished_page", fn ->
          Enum.map(
            [
              Sections.get_last_open_and_unfinished_page(section, current_user_id),
              nearest_upcoming_lesson
            ],
            fn
              nil ->
                nil

              page ->
                page_module_index =
                  section
                  |> SectionResourceDepot.get_full_hierarchy(hidden: false)
                  |> Hierarchy.find_module_ancestor(
                    Map.get(page, :resource_id),
                    Oli.Resources.ResourceType.get_id_by_type("container")
                  )
                  |> get_in(["numbering", "index"])

                Map.put(page, :module_index, page_module_index)
            end
          )
        end)

      {
        :ok,
        assign(socket,
          active_tab: :index,
          loaded: true,
          grouped_agenda_resources:
            Utils.grouped_agenda_resources(
              section,
              combined_settings,
              current_user_id,
              has_scheduled_resources?
            ),
          section_slug: section.slug,
          section_start_date: section.start_date,
          historical_graded_attempt_summary: nil,
          has_scheduled_resources?: has_scheduled_resources?,
          has_visited_section:
            Sections.has_visited_section(section, socket.assigns[:current_user],
              enrollment_state: false
            ),
          last_open_and_unfinished_page: last_open_and_unfinished_page,
          nearest_upcoming_lesson: nearest_upcoming_lesson,
          upcoming_assignments: combine_settings(upcoming_assignments, combined_settings),
          latest_assignments: combine_settings(latest_assignments, combined_settings),
          containers_per_page: containers_per_page,
          assignments_tab: :upcoming,
          completed_pages: get_completed_pages(section.id, current_user_id),
          certificate_enabled: certificate_enabled
        )
        |> assign_async(:certificate_progress, fn ->
          {:ok,
           %{
             certificate_progress:
               maybe_get_certificate_progress(certificate_enabled, current_user_id, section.id)
           }}
        end)
      }
    else
      {:ok, assign(socket, active_tab: :index, loaded: false)}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def handle_event(
        "load_historical_graded_attempt_summary",
        %{"page_revision_slug" => page_revision_slug},
        socket
      ) do
    %{section: section, current_user: current_user} = socket.assigns

    historical_graded_attempt_summary =
      Attempts.get_historical_graded_attempt_summary(section, page_revision_slug, current_user.id)

    {:noreply,
     assign(socket, historical_graded_attempt_summary: historical_graded_attempt_summary)}
  end

  def handle_event("clear_historical_graded_attempt_summary", _params, socket) do
    {:noreply, assign(socket, historical_graded_attempt_summary: nil)}
  end

  def handle_event("toggle_assignments_tab", _params, socket) do
    case socket.assigns.assignments_tab do
      :upcoming -> {:noreply, assign(socket, assignments_tab: :latest)}
      :latest -> {:noreply, assign(socket, assignments_tab: :upcoming)}
    end
  end

  def render(%{loaded: false} = assigns) do
    ~H"""
    <div></div>
    """
  end

  def render(assigns) do
    ~H"""
    <.header_banner
      ctx={@ctx}
      section_slug={@section_slug}
      section={@section}
      has_visited_section={@has_visited_section}
      suggested_page={@last_open_and_unfinished_page || @nearest_upcoming_lesson}
      unfinished_lesson={!is_nil(@last_open_and_unfinished_page)}
      has_scheduled_resources?={@has_scheduled_resources?}
    />
    <div id="home-view" class="bg-stone-950 dark:text-white" phx-hook="Countdown">
      <div class="flex flex-col md:flex-row p-3 md:p-8 justify-start items-start gap-6">
        <div class={[
          if(@section.agenda,
            do:
              "flex flex-col-reverse md:flex-col w-full md:w-2/5 md:h-48 justify-start items-start gap-6",
            else: "flex w-full gap-6"
          )
        ]}>
          <.assignments
            upcoming_assignments={@upcoming_assignments}
            latest_assignments={@latest_assignments}
            section_slug={@section_slug}
            assignments_tab={@assignments_tab}
            containers_per_page={@containers_per_page}
            ctx={@ctx}
          />
          <.course_progress
            :if={@completed_pages.total_pages > 0}
            has_visited_section={@has_visited_section}
            page_completed_target_path={
              ~p"/sections/#{@section_slug}/learn?sidebar_expanded=#{@sidebar_expanded}"
            }
            completed_pages={@completed_pages}
            certificate_enabled={@certificate_enabled}
            certificate_progress={@certificate_progress}
            section_slug={@section_slug}
          />
        </div>

        <div
          :if={@section.agenda && not is_nil(@grouped_agenda_resources)}
          class="flex flex-col w-full md:w-3/5 justify-start items-start gap-6"
        >
          <.agenda
            section_slug={@section_slug}
            grouped_agenda_resources={@grouped_agenda_resources}
            has_scheduled_resources?={@has_scheduled_resources?}
            section_start_date={@section_start_date}
            ctx={@ctx}
          />
        </div>
      </div>
    </div>
    """
  end

  attr(:ctx, :map, default: nil)
  attr(:section_slug, :string, required: true)
  attr(:section, :any, required: true)
  attr(:has_visited_section, :boolean, required: true)
  attr(:suggested_page, :map)
  attr(:unfinished_lesson, :boolean, required: true)
  attr(:has_scheduled_resources?, :boolean, required: true)

  defp header_banner(%{has_visited_section: true} = assigns) do
    ~H"""
    <div class="w-full h-[20rem] md:h-72 relative flex items-center">
      <div class="inset-0 absolute">
        <div class="inset-0 absolute bg-purple-700 bg-opacity-50"></div>
        <img
          src="/images/gradients/home-bg.png"
          alt="Background Image"
          class="absolute inset-0 w-full h-full object-cover border border-gray-300 dark:border-black mix-blend-luminosity"
        />
        <div class="absolute inset-0 opacity-60">
          <div class="absolute left-[1250px] top-0 origin-top-left rotate-180 bg-gradient-to-r from-white to-white">
          </div>
          <div class="absolute inset-0 bg-gradient-to-r from-blue-700 to-cyan-500"></div>
        </div>
      </div>

      <div
        :if={!is_nil(@suggested_page)}
        class="flex flex-col w-full px-3 md:px-9 absolute justify-center items-start gap-2 md:gap-6"
      >
        <h3 class="text-white text-lg md:text-2xl font-bold leading-loose tracking-tight">
          Continue Learning
        </h3>
        <div class="flex flex-col lg:flex-row self-stretch p-6 bg-zinc-900 bg-opacity-40 rounded-xl justify-between lg:items-end gap-3">
          <div class="flex-col justify-center items-start gap-3.5 inline-flex">
            <div class="self-stretch h-3 justify-start items-center gap-3.5 inline-flex">
              <div
                :if={show_page_module?(@suggested_page)}
                class="justify-start items-start gap-1 flex"
              >
                <div class="opacity-50 text-white text-sm font-bold uppercase tracking-tight">
                  Module <%= @suggested_page.module_index %>
                </div>
              </div>
              <div
                :if={@has_scheduled_resources?}
                class="grow shrink basis-0 h-5 justify-start items-center gap-1 flex"
              >
                <div class="text-right text-white text-sm font-bold">Due:</div>
                <div class="text-right text-white text-sm font-bold">
                  <%= format_date(
                    @suggested_page.end_date,
                    @ctx,
                    "{WDshort} {Mshort} {D}, {YYYY}"
                  ) %>
                </div>
              </div>
            </div>
            <div class="justify-start items-center gap-10 inline-flex">
              <div class="justify-start items-center gap-5 flex">
                <div class="py-0.5 justify-start items-start gap-2.5 flex">
                  <div class="text-white text-xs font-semibold">
                    <%= @suggested_page.numbering_index %>
                  </div>
                </div>
                <div class="flex-col justify-center items-start gap-1 inline-flex">
                  <div class="text-white md:text-lg font-semibold">
                    <%= @suggested_page.title %>
                  </div>
                </div>
              </div>
              <div
                :if={@suggested_page.duration_minutes}
                class="w-36 self-stretch justify-end items-center gap-1.5 flex"
              >
                <div class="h-6 px-2 py-1 bg-white bg-opacity-10 rounded-xl shadow justify-end items-center gap-1 flex">
                  <div class="text-white text-xs font-semibold">
                    Estimated time <%= @suggested_page.duration_minutes %> m
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="flex flex-col md:flex-row justify-end items-start gap-3.5">
            <.link
              href={
                Utils.lesson_live_path(
                  @section_slug,
                  @suggested_page.slug,
                  request_path: ~p"/sections/#{@section_slug}"
                )
              }
              class="w-full hover:no-underline"
            >
              <div class="px-5 py-2.5 bg-blue-600 rounded-lg shadow justify-center items-center gap-2.5 flex hover:bg-blue-500">
                <div class="text-white text-sm font-bold leading-tight whitespace-nowrap">
                  <%= lesson_button_label(@unfinished_lesson, @suggested_page) %>
                </div>
              </div>
            </.link>
            <.link
              href={
                Utils.learn_live_path(@section_slug,
                  target_resource_id: @suggested_page.resource_id,
                  request_path: ~p"/sections/#{@section_slug}"
                )
              }
              class="w-full hover:no-underline"
            >
              <div class="px-5 py-2.5 bg-white bg-opacity-20 rounded-lg shadow justify-center items-center gap-2.5 flex hover:bg-opacity-40">
                <div class="text-white text-sm font-semibold leading-tight whitespace-nowrap">
                  Show in course
                </div>
              </div>
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp header_banner(assigns) do
    ~H"""
    <div class="w-full h-[20rem] md:h-72 relative flex items-center">
      <div class="inset-0 absolute">
        <div class="inset-0 absolute bg-purple-700 bg-opacity-50"></div>
        <img
          src="/images/gradients/home-bg.png"
          alt="Background Image"
          class="absolute inset-0 w-full h-full object-cover border border-gray-300 dark:border-black mix-blend-luminosity"
        />
        <div class="absolute inset-0 opacity-60">
          <div class="absolute left-[1250px] top-0 origin-top-left rotate-180 bg-gradient-to-r from-white to-white">
          </div>
          <div class="absolute inset-0 bg-gradient-to-r from-blue-700 to-cyan-500"></div>
        </div>
      </div>

      <div class="flex flex-col w-full px-9 absolute flex-col justify-center items-start gap-2 md:gap-6">
        <h3 class="w-full text-white text-2xl font-bold tracking-wide">
          Hi, <%= user_given_name(@ctx) %> !
        </h3>
        <div class="flex flex-col items-start gap-2.5">
          <h4 class="text-3xl text-white font-medium">
            <%= build_welcome_title(@section.welcome_title) %>
          </h4>
          <div class="text-white/60 text-lg font-semibold">
            <%= @section.encouraging_subtitle ||
              "Dive Into Discovery. Begin Your Learning Adventure Now!" %>
          </div>
        </div>
        <div class="flex flex-col md:flex-row w-full justify-end items-start gap-3.5">
          <.link
            href={
              Utils.lesson_live_path(
                @section_slug,
                DeliveryResolver.get_first_page_slug(@section_slug),
                request_path: ~p"/sections/#{@section_slug}"
              )
            }
            class="w-full md:w-auto hover:no-underline"
          >
            <div class="px-5 py-2.5 bg-blue-600 rounded-lg shadow flex justify-center items-center gap-2.5 hover:bg-blue-500">
              <div class="text-white text-base font-bold leading-tight whitespace-nowrap">
                Start course
              </div>
            </div>
          </.link>
          <.link
            href={Utils.learn_live_path(@section_slug)}
            class="w-full md:w-auto hover:no-underline"
          >
            <div class="px-5 py-2.5 bg-white bg-opacity-20 rounded-lg shadow flex justify-center items-center gap-2.5 hover:bg-opacity-40">
              <div class="text-white text-base font-semibold leading-tight whitespace-nowrap">
                Discover content
              </div>
            </div>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  attr(:has_visited_section, :boolean, required: true)
  attr(:page_completed_target_path, :string, required: true)
  attr(:completed_pages, :map, required: true)
  attr(:certificate_enabled, :boolean, required: true)
  attr(:certificate_progress, :map, required: true)
  attr(:section_slug, :string, required: true)

  defp course_progress(assigns) do
    ~H"""
    <div class="absolute">
      <Modal.modal
        id="course_progress_calculation_modal"
        class="mx-52"
        header_class="flex items-start justify-between px-[35px] pt-[27px] pb-4"
        body_class="border-t border-[#d4d4d4] dark:border-[#3e3f44] px-[35px] pb-[50px] pt-[30px]"
      >
        <:title>Course Progress Calculation</:title>
        <div class="dark:text-white text-base">
          <div class="w-[797px] font-bold mb-9">
            Lesson Page Progress
          </div>
          <div class="flex-col justify-start items-start gap-[31px] inline-flex">
            <div class="self-stretch justify-start items-start gap-3 inline-flex">
              <div class="px-3 py-1 bg-[#deecff] dark:bg-[#363b59] rounded-[999px] justify-start items-center gap-1.5 flex">
                <div class="w-5 h-5 relative text-[#1b67b2] dark:text-[#99ccff]">
                  <Icons.clipboard />
                </div>
              </div>
              <div class="pb-[3px] justify-end items-center flex">
                <div class="self-stretch pr-[13px] justify-start items-center inline-flex">
                  <div class="">
                    <span class="font-bold">
                      Practice Pages with Activities:
                    </span>
                    <span class="font-medium">
                      Achieve 100% progress if you have
                    </span>
                    <span class="font-bold">attempted</span><span class="font-medium"> </span><span class="font-bold">every activity</span><span class="font-medium"> on that page at least once. Surveys do not count towards progress.</span>
                  </div>
                </div>
              </div>
            </div>
            <div class="justify-start items-center gap-3 inline-flex">
              <div class="px-3 py-1 bg-[#dcf3f5] dark:bg-[#364147] rounded-[999px] justify-start items-center gap-1.5 flex">
                <div class="w-5 h-5 relative text-[#00808f] dark:text-[#87d7e0]"><Icons.book /></div>
              </div>
              <div class="">
                <span class="font-bold">
                  Practice Pages without Activities:
                </span>
                <span class="font-medium">
                  Achieve 100% progress if you have
                </span>
                <span class="font-bold">visited</span><span class="font-medium"> the page at least once.</span>
              </div>
            </div>
            <div class="justify-start items-center gap-3 inline-flex">
              <div class="px-3 py-1 bg-[#ffecde] dark:bg-[#4c3f39] rounded-[999px] justify-start items-center gap-1.5 flex">
                <div class="w-5 h-5 relative text-[#bf5b13] dark:text-[#ffb387]">
                  <Icons.transparent_flag />
                </div>
              </div>
              <div>
                <span class="font-bold">
                  Scored Assignments:
                </span>
                <span class="font-medium">
                  Achieve 100% progress on scored assignments if you
                </span>
                <span class="font-bold">submit</span><span class="font-medium"> at least one attempt. </span>
              </div>
            </div>
          </div>
          <div class="mt-12">
            <div class="self-stretch font-bold mb-6">
              Average Progress
            </div>
            <div class="self-stretch flex-col justify-start items-end flex">
              <div class="self-stretch font-medium">
                The calculation logic for course progress is based on averaging the completion percentages of individual lesson pages within a container (like a module or unit).
              </div>
            </div>
          </div>
        </div>
      </Modal.modal>
    </div>
    <div class="w-full h-fit p-6 bg-white shadow dark:bg-[#1C1A20] dark:bg-opacity-100 rounded-2xl justify-start items-start inline-flex">
      <div class="flex-col justify-start items-start gap-3 md:gap-5 inline-flex grow">
        <div class="flex items-baseline gap-2.5 relative">
          <div class="text-2xl font-bold leading-loose">
            Course Progress
          </div>
          <div
            id="course_progress_tooltip"
            phx-hook="AutoHideTooltip"
            class="hidden absolute z-50 -top-[89px] -right-[316px] p-4"
          >
            <div class="w-[320px] h-[88px] px-4 py-2 bg-white dark:bg-[#0d0c0f] rounded-md shadow border border-[#ced1d9] dark:border-[#3a3740]">
              <div class="grow shrink basis-0">
                <span class="text-[#353740] dark:text-[#eeebf5] text-sm font-normal leading-normal">
                  Course progress is calculated based on the pages you visit and the percentage of activities you complete.
                </span>
                <button
                  phx-click={
                    Modal.show_modal("course_progress_calculation_modal")
                    |> JS.hide(to: "#course_progress_tooltip")
                  }
                  class="text-[#353740] dark:text-[#eeebf5] text-sm font-bold underline leading-normal"
                >
                  Learn more.
                </button>
              </div>
            </div>
          </div>
          <span
            xphx-mouseover={JS.show(to: "#course_progress_tooltip")}
            class="size-5 hover:cursor-pointer"
          >
            <Icons.info />
          </span>
        </div>
        <%= if @has_visited_section do %>
          <div class="flex-col justify-start items-start flex">
            <div>
              <span class="text-3xl md:text-6xl font-bold leading-[76px]">
                <%= parse_progress(@completed_pages.completed_pages / @completed_pages.total_pages) %>
              </span>
              <span class="text-xl md:text-3xl font-bold leading-[44px]">%</span>
            </div>
          </div>
          <Common.progress_bar
            percent={@completed_pages.completed_pages / @completed_pages.total_pages * 100}
            on_going_colour="bg-[#0CAF61] dark:bg-[#0fb863]"
            completed_colour="bg-[#0CAF61] dark:bg-[#0fb863]"
            not_completed_colour="bg-[#385581]"
            role="course progress bar"
            show_percent={false}
            show_halo={true}
          />
          <.link
            navigate={@page_completed_target_path}
            class="text-[#4ca6ff] dark:text-[#3399FF] text-base font-bold ml-auto hover:text-opacity-80 hover:no-underline"
          >
            <%= @completed_pages.completed_pages %>/<%= @completed_pages.total_pages %> Pages Completed
          </.link>
        <% else %>
          <div class="justify-start items-center gap-1 inline-flex self-stretch">
            <div class="text-base font-normal tracking-tight grow">
              Begin your learning journey to watch your progress unfold here!
            </div>
          </div>
        <% end %>
        <.certificate_progress
          :if={@certificate_enabled}
          certificate_progress={@certificate_progress}
          section_slug={@section_slug}
        />
      </div>
    </div>
    """
  end

  attr :certificate_progress, :map, required: true
  attr :section_slug, :string, required: true

  def certificate_progress(assigns) do
    ~H"""
    <div
      id="certificate_progress_card"
      class="flex flex-col w-full bg-black/10 dark:bg-[#2b282e] rounded-xl p-6 before:bg-[#0CAF61] dark:before:bg-[#39e581] relative overflow-hidden z-0 before:content-[''] before:absolute before:left-0 before:top-0 before:w-0.5 before:h-full before:z-10"
    >
      <div class="flex justify-between dark:text-[#eeebf5] text-lg font-semibold leading-normal">
        <div>Certificate Progress</div>
        <div class="h-7 px-3 py-1 bg-[#39e581]/25 rounded-[999px] flex items-center justify-center">
          <div class="w-6 h-6 overflow-hidden"><Icons.certificate /></div>
        </div>
      </div>
      <div class="dark:text-[#e6e9f2] text-base font-normal mt-4 mb-8">
        <span>Complete </span>
        <span class="dark:text-white font-bold">all </span>
        <span>of the specified requirements to achieve a certificate.</span>
      </div>

      <.async_result :let={certificate_progress} assign={@certificate_progress}>
        <:loading>Loading progress...</:loading>
        <:failed :let={_failure}>there was an error loading the certificate progress</:failed>
        <div class="flex flex-col space-y-8">
          <div
            :if={certificate_progress.discussion_posts.total > 0}
            id="certificate_discussion_posts_progress"
            class="flex-col justify-start items-start gap-3 inline-flex"
          >
            <div class="justify-start items-center gap-3 inline-flex">
              <div class="w-5 h-5 overflow-hidden">
                <Icons.message class="dark:stroke-white stroke-black" />
              </div>
              <div class="dark:text-[#eeebf5] text-base font-bold leading-normal">
                Discussion Posts
              </div>
            </div>
            <div class="justify-center items-center gap-3 inline-flex">
              <div class="w-5 h-5 overflow-hidden"><Icons.check /></div>
              <div class="dark:text-white text-sm font-normal leading-none">
                <%= certificate_progress_text(
                  certificate_progress.discussion_posts,
                  "Discussion Post"
                ) %>
              </div>
            </div>
          </div>

          <div
            :if={certificate_progress.class_notes.total > 0}
            id="certificate_class_notes_progress"
            class="flex-col justify-start items-start gap-3 inline-flex"
          >
            <div class="justify-start items-center gap-3 inline-flex">
              <div class="w-5 h-5 overflow-hidden"><Icons.message_circles /></div>
              <div class="dark:text-[#eeebf5] text-base font-bold leading-normal">
                Class Notes
              </div>
            </div>
            <div class="justify-center items-center gap-3 inline-flex">
              <div class="w-5 h-5 overflow-hidden"><Icons.check /></div>
              <div class="dark:text-white text-sm font-normal leading-none">
                <%= certificate_progress_text(
                  certificate_progress.class_notes,
                  "Class Note"
                ) %>
              </div>
            </div>
          </div>

          <div
            :if={certificate_progress.required_assignments.total > 0}
            id="certificate_required_assignments_progress"
            class="flex-col justify-start items-start gap-3 inline-flex"
          >
            <div class="justify-start items-center gap-3 inline-flex">
              <div class="w-5 h-5 overflow-hidden dark:text-white">
                <Icons.transparent_flag class="dark:stroke-white" />
              </div>
              <div class="dark:text-[#eeebf5] text-base font-bold leading-normal">
                Required Assignments
              </div>
            </div>
            <div class="justify-center items-center gap-3 inline-flex">
              <div class="w-5 h-5 overflow-hidden"><Icons.check /></div>
              <div class="dark:text-white text-sm font-normal leading-none">
                <%= certificate_progress_text(
                  certificate_progress.required_assignments,
                  "Required Assignment"
                ) %>
              </div>
            </div>
          </div>
          <div
            :if={certificate_progress.granted_certificate_state == :denied}
            class="text-base font-bold"
          >
            Certificate was denied by instructor
          </div>
          <div
            :if={certificate_progress.granted_certificate_state == :pending}
            class="text-base font-bold"
          >
            Your certificate is pending instructor approval…
          </div>
          <.link
            :if={
              all_certificate_requirements_met?(certificate_progress) and
                certificate_progress.granted_certificate_state == :earned
            }
            navigate={
              ~p"/sections/#{@section_slug}/certificate/#{certificate_progress.granted_certificate_guid}"
            }
            class=" text-[#4ca6ff] dark:text-[#3399FF] text-base font-bold ml-auto hover:text-opacity-80 hover:no-underline"
          >
            Access my certificate
          </.link>
        </div>
      </.async_result>
    </div>
    """
  end

  defp maybe_get_certificate_progress(false, _user_id, _section_id), do: %{}

  defp maybe_get_certificate_progress(true, user_id, section_id),
    do: Certificates.raw_student_certificate_progress(user_id, section_id)

  defp certificate_progress_text(%{completed: completed, total: total}, _label)
       when completed >= total,
       do: "Completed"

  defp certificate_progress_text(%{completed: completed, total: total}, label) do
    "#{completed} of #{total} #{label}#{if total > 1, do: "s", else: ""}"
  end

  defp all_certificate_requirements_met?(certificate_progress),
    do:
      Map.drop(certificate_progress, [:granted_certificate_guid, :granted_certificate_state])
      |> Enum.all?(fn {_criteria, result} ->
        result.completed >= result.total
      end)

  attr(:upcoming_assignments, :list, required: true)
  attr(:latest_assignments, :list, default: [])
  attr(:section_slug, :string, required: true)
  attr(:assignments_tab, :atom, required: true)
  attr(:containers_per_page, :map, required: true)
  attr(:ctx, :map, required: true)

  defp assignments(assigns) do
    lessons =
      case assigns.assignments_tab do
        :upcoming -> assigns.upcoming_assignments
        :latest -> assigns.latest_assignments
      end

    assigns = Map.put(assigns, :lessons, lessons)

    ~H"""
    <div
      role="my assignments"
      class="w-full p-6 bg-white shadow dark:bg-[#1C1A20] dark:bg-opacity-100 rounded-2xl justify-start items-start gap-32 inline-flex"
    >
      <div class="w-full flex-col justify-start items-start gap-5 flex grow">
        <div class="w-full xl:w-48 overflow-hidden justify-start items-start gap-2.5 flex">
          <div class="text-2xl font-bold leading-loose tracking-tight">
            My Assignments
          </div>
        </div>
        <div class="w-full h-fit overflow-hidden dark:text-white justify-start items-start gap-3.5 flex xl:flex-row flex-col">
          <button
            id="upcoming_tab"
            phx-click="toggle_assignments_tab"
            class={assignments_tab_class(@assignments_tab, :upcoming)}
          >
            <div class="pr-1 text-lg tracking-tight font-bold whitespace-nowrap">
              Upcoming
            </div>
          </button>
          <button
            id="latest_tab"
            phx-click="toggle_assignments_tab"
            class={assignments_tab_class(@assignments_tab, :latest)}
          >
            <div class="grow shrink basis-0 text-lg tracking-tight font-bold">Latest</div>
          </button>
        </div>
        <div role="assignments" class="w-full h-fit flex-col justify-start items-start gap-2.5 flex">
          <%= if Enum.empty?(@lessons) do %>
            <div role="message" class="flex-col justify-start items-start gap-2.5 flex">
              <div class="dark:text-white text-base font-normal font-sans tracking-[0.32px] break-words">
                <%= empty_assignments_message(@assignments_tab) %>
              </div>
            </div>
          <% else %>
            <.lesson_card
              :for={lesson <- @lessons}
              upcoming={@assignments_tab == :upcoming}
              lesson={lesson}
              containers={@containers_per_page[lesson.resource_id] || []}
              section_slug={@section_slug}
              ctx={@ctx}
            />
          <% end %>
        </div>
        <.link
          navigate={
            Utils.assignments_live_path(
              @section_slug,
              request_path: ~p"/sections/#{@section_slug}"
            )
          }
          class="text-[#4ca6ff] dark:text-[#3399FF] text-base font-bold ml-auto hover:text-opacity-80 hover:no-underline"
        >
          View All Assignments
        </.link>
      </div>
    </div>
    """
  end

  defp assignments_tab_class(tab, tab), do: "pointer-events-none cursor-not-allowed"
  defp assignments_tab_class(_, _), do: "opacity-40 hover:opacity-70"

  defp empty_assignments_message(:upcoming),
    do: "Great job, you completed all the assignments! There are no upcoming assignments."

  defp empty_assignments_message(:latest),
    do: "It looks like you need to start your attempt. Begin with the upcoming assignments!"

  attr(:lesson, :map, required: true)
  attr(:upcoming, :boolean, required: true)
  attr(:section_slug, :string, required: true)
  attr(:containers, :list, required: true)
  attr(:ctx, :map, required: true)

  defp lesson_card(assigns) do
    assigns =
      Map.merge(assigns, %{
        lesson_type: Student.type_from_resource(assigns.lesson),
        completed: !assigns.upcoming and completed_lesson?(assigns.lesson),
        unit: Enum.find(assigns.containers, fn c -> c["numbering_level"] == 1 end),
        module: Enum.find(assigns.containers, fn c -> c["numbering_level"] == 2 end)
      })

    ~H"""
    <.link
      href={
        Utils.lesson_live_path(@section_slug, @lesson.slug,
          request_path: ~p"/sections/#{@section_slug}"
        )
      }
      class="w-full text-black hover:text-black hover:no-underline"
    >
      <div class={[
        left_bar_color(@lesson_type),
        item_bg_color(@completed),
        "flex h-full px-2.5 py-3.5 rounded-xl border flex-col justify-start items-start hover:cursor-pointer relative overflow-hidden z-0 before:content-[''] before:absolute before:left-0 before:top-0 before:w-0.5 before:h-full before:z-10"
      ]}>
        <div class="self-stretch justify-between items-start flex pl-2">
          <div class="grow shrink basis-0 self-stretch flex-col justify-start items-start gap-2.5 flex">
            <div role="container_label" class="justify-start items-start gap-2 flex uppercase">
              <div class="dark:text-white text-opacity-60 text-xs font-bold whitespace-nowrap">
                <%= @unit["label"] %>
              </div>

              <div :if={@module} class="flex items-center gap-2">
                <div class="dark:text-white text-opacity-60 text-xs font-bold">•</div>
                <div class="dark:text-white text-opacity-60 text-xs font-bold whitespace-nowrap">
                  <%= @module["label"] %>
                </div>
              </div>
            </div>
            <div role="title" class="self-stretch pb-2.5 justify-start items-start gap-2.5 flex">
              <div class="grow shrink basis-0 dark:text-white text-opacity-90 text-lg font-semibold">
                <%= @lesson.title %>
              </div>
            </div>
          </div>
          <Student.resource_type type={@lesson_type} long={false} />
        </div>

        <.lesson_details upcoming={@upcoming} lesson={@lesson} completed={@completed} ctx={@ctx} />
      </div>
    </.link>
    """
  end

  defp left_bar_color(:checkpoint), do: "before:bg-checkpoint dark:before:bg-checkpoint-dark"
  defp left_bar_color(:practice), do: "before:bg-practice dark:before:bg-practice-dark"
  defp left_bar_color(:exploration), do: "before:bg-exploration dark:before:bg-exploration-dark"
  defp left_bar_color(_), do: ""

  defp item_bg_color(true = _completed),
    do:
      "bg-black/[.07] hover:bg-black/[.1] border border-white/[.1] dark:bg-white/[.02] dark:hover:bg-white/[.06] dark:border-white/[0.06] dark:hover:border-white/[0.02]"

  defp item_bg_color(false = _completed),
    do:
      "bg-black/[.1] hover:bg-black/[.2] border border-white/[.6] hover:border-transparent dark:bg-white/[.08] dark:hover:bg-white/[.12] dark:border-black hover:!border-transparent"

  attr :lesson, :map, required: true
  attr :upcoming, :boolean, required: true
  attr :completed, :boolean, required: true
  attr :ctx, :map, required: true

  defp lesson_details(%{upcoming: true} = assigns) do
    ~H"""
    <div role="details" class="w-full h-full flex flex-col items-stretch gap-5 relative">
      <div class="pr-2 pl-1 self-end">
        <div class="flex items-end gap-1">
          <div
            :if={!is_nil(@lesson.start_date) and !is_nil(@lesson.end_date)}
            class="text-right dark:text-white text-opacity-90 text-xs font-semibold"
          >
            <%= if is_nil(@lesson.settings),
              do:
                Utils.coalesce(@lesson.end_date, @lesson.start_date)
                |> Utils.days_difference(@lesson.scheduling_type, @ctx),
              else:
                Utils.coalesce(@lesson.settings.end_date, @lesson.end_date)
                |> Utils.coalesce(@lesson.settings.start_date)
                |> Utils.coalesce(@lesson.start_date)
                |> Utils.days_difference(@lesson.settings.scheduling_type, @ctx) %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Completed page
  defp lesson_details(%{completed: true} = assigns) do
    ~H"""
    <div role="details" class="pt-2 pb-1 px-1 flex self-stretch justify-between gap-5">
      <div class="justify-end items-end gap-2.5 flex ml-auto">
        <div class="flex items-end gap-1">
          <div class="text-right dark:text-white text-opacity-90 text-xs font-semibold">
            Completed
          </div>
          <Icons.check progress={1.0} />
        </div>
      </div>
    </div>
    """
  end

  # Non-completed graded page (assignment)
  defp lesson_details(%{lesson: %{graded: true, batch_scoring: false}} = assigns) do
    ~H"""
    <div role="details" class="pt-2 pb-1 px-1 flex self-stretch justify-between gap-5">
      <div class="flex justify-between gap-2.5 w-full">
        <div>Score as you go</div>
        <div class="text-green-700 dark:text-green-500 flex justify-end items-center gap-1">
          <div class="relative"><Icons.score_as_you_go /></div>
          <div role="score" class="text-sm font-semibold tracking-tight">
            <%= Utils.format_score(@lesson.score) %>
          </div>
          <div class="text-sm font-semibold tracking-widest">
            /
          </div>
          <div role="out_of" class="text-sm font-semibold tracking-tight">
            <%= Utils.format_score(@lesson.out_of) %>
          </div>
        </div>
      </div>
      <div
        :if={lesson_expires?(@lesson)}
        class="w-fit h-4 pl-1 justify-center items-start gap-1 inline-flex"
      >
        <div class="opacity-50 text-black dark:text-white text-xs font-normal">
          Time Remaining:
        </div>
        <div
          role="countdown"
          class={[
            if(@lesson.purpose == :application,
              do: "text-exploration dark:text-exploration-dark",
              else: "text-checkpoint dark:text-checkpoint-dark"
            ),
            "text-xs font-normal"
          ]}
        >
          <%= effective_lesson_expiration_date(@lesson) |> Utils.format_time_remaining() %>
        </div>
      </div>
    </div>
    """
  end

  # Non-completed graded page (assignment)
  defp lesson_details(%{lesson: %{graded: true}} = assigns) do
    ~H"""
    <div role="details" class="pt-2 pb-1 px-1 flex self-stretch justify-between gap-5">
      <%= if @lesson.last_attempt_state != :active do %>
        <div class="flex px-2 py-0.5 bg-white/10 rounded-xl shadow tracking-tight gap-2 items-center align-center">
          <div role="count" class="pl-1 justify-start items-center gap-2.5 flex">
            <div class="dark:text-white text-xs font-semibold">
              Attempt <%= "#{@lesson.attempts_count}/#{max_attempts(@lesson.settings.max_attempts)}" %>
            </div>
          </div>
        </div>
      <% else %>
        <div
          :if={lesson_expires?(@lesson)}
          class="w-fit h-4 pl-1 justify-center items-start gap-1 inline-flex"
        >
          <div class="opacity-50 text-black dark:text-white text-xs font-normal">
            Time Remaining:
          </div>
          <div
            role="countdown"
            class={[
              if(@lesson.purpose == :application,
                do: "text-exploration dark:text-exploration-dark",
                else: "text-checkpoint dark:text-checkpoint-dark"
              ),
              "text-xs font-normal"
            ]}
          >
            <%= effective_lesson_expiration_date(@lesson) |> Utils.format_time_remaining() %>
          </div>
        </div>
      <% end %>
      <div
        :if={nil not in [@lesson.score, @lesson.out_of]}
        class="justify-end items-end gap-2.5 flex ml-auto"
      >
        <div class="text-green-700 dark:text-green-500 flex justify-end items-center gap-1">
          <div class="w-4 h-4 relative"><Icons.star /></div>
          <div role="score" class="text-sm font-semibold tracking-tight">
            <%= Utils.format_score(@lesson.score) %>
          </div>
          <div class="text-sm font-semibold tracking-widest">
            /
          </div>
          <div role="out_of" class="text-sm font-semibold tracking-tight">
            <%= Utils.format_score(@lesson.out_of) %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Non-completed practice page
  defp lesson_details(assigns) do
    ~H"""
    <div role="details" class="pt-2 pb-1 px-1 flex self-stretch justify-between gap-5">
      <div
        :if={lesson_expires?(@lesson)}
        class="w-fit h-4 pl-1 justify-center items-start gap-1 inline-flex"
      >
        <div class="opacity-50 text-black dark:text-white text-xs font-normal">
          Time Remaining:
        </div>
        <div role="countdown" class="text-practice dark:text-practice-dark text-xs font-normal">
          <%= effective_lesson_expiration_date(@lesson) |> Utils.format_time_remaining() %>
        </div>
      </div>
    </div>
    """
  end

  defp lesson_expires?(lesson) do
    Utils.attempt_expires?(
      lesson.last_attempt_state,
      lesson.settings.time_limit,
      lesson.settings.late_submit,
      lesson.end_date
    )
  end

  defp effective_lesson_expiration_date(lesson) do
    Utils.effective_attempt_expiration_date(
      lesson.last_attempt_started_at,
      lesson.settings.time_limit,
      lesson.settings.late_submit,
      lesson.end_date
    )
  end

  defp completed_lesson?(%{graded: true} = assignment),
    do:
      assignment.attempts_count == assignment.settings.max_attempts and
        assignment.last_attempt_state != :active

  defp completed_lesson?(practice), do: practice.progress == 1.0

  attr(:section_slug, :string, required: true)
  attr(:section_start_date, :string, required: true)
  attr(:grouped_agenda_resources, :map, required: true)
  attr(:has_scheduled_resources?, :boolean, required: true)
  attr(:ctx, :map, required: true)

  defp agenda(assigns) do
    ~H"""
    <div class="w-full h-fit overflow-y-auto p-6 bg-white shadow dark:bg-[#1C1A20] dark:bg-opacity-100 rounded-2xl justify-start items-start gap-32 inline-flex">
      <div class="flex-col justify-start items-start gap-7 inline-flex grow">
        <div class="self-stretch justify-between items-baseline inline-flex gap-2.5">
          <div class="text-2xl font-bold leading-loose tracking-tight">
            Upcoming Agenda
          </div>
          <.link
            :if={@has_scheduled_resources?}
            href={
              Utils.schedule_live_path(
                @section_slug,
                request_path: ~p"/sections/#{@section_slug}"
              )
            }
            class="hover:no-underline"
          >
            <div class="text-[#3399FF] hover:text-opacity-80 text-base font-bold tracking-tight">
              View full schedule
            </div>
          </.link>
        </div>
        <.live_component
          module={ScheduleComponent}
          ctx={@ctx}
          id="schedule_component"
          grouped_agenda_resources={@grouped_agenda_resources}
          section_start_date={@section_start_date}
          section_slug={@section_slug}
          has_scheduled_resources?={@has_scheduled_resources?}
        />
      </div>
    </div>
    """
  end

  defp format_date(nil, _context, _format), do: "Not yet scheduled"

  defp format_date(due_date, context, format) do
    FormatDateTime.to_formatted_datetime(due_date, context, format)
  end

  # Do not show the module index if it does not exist or the page is not graded or is an exploration
  defp show_page_module?(page) do
    !(is_nil(page.module_index) or !page.graded or page.purpose == :application)
  end

  defp lesson_button_label(unfinished_lesson?, page) do
    if(unfinished_lesson?,
      do: "Resume",
      else: "Start"
    ) <>
      cond do
        !page.graded -> " practice"
        page.purpose == :application -> " exploration"
        true -> " lesson"
      end
  end

  defp parse_progress(progress) do
    progress
    |> Kernel.*(100)
    |> round()
    |> trunc()
  end

  defp build_welcome_title(welcome_title)
       when welcome_title not in [nil, %{}],
       do:
         Phoenix.HTML.raw(
           Oli.Rendering.Content.render(
             %Oli.Rendering.Context{},
             welcome_title["children"],
             Oli.Rendering.Content.Html
           )
         )

  defp build_welcome_title(_), do: "Welcome to the Course"

  defp max_attempts(0), do: "∞"
  defp max_attempts(max_attempts), do: max_attempts

  defp build_containers_per_page(section, page_ids) do
    containers_label_map =
      Sections.get_ordered_container_labels(section.slug, short_label: true)
      |> Enum.reduce(%{}, fn {container_id, label}, acc ->
        Map.put(acc, container_id, label)
      end)

    add_label_to_containers =
      &Enum.map(&1, fn container ->
        Map.put(container, "label", containers_label_map[container["id"]])
      end)

    Sections.get_ordered_containers_per_page(section, page_ids)
    |> Enum.reduce(%{}, fn elem, acc ->
      Map.put(acc, elem[:page_id], add_label_to_containers.(elem[:containers]))
    end)
  end

  defp combine_settings(assignments, settings) do
    Enum.map(assignments, fn assignment ->
      Map.put(assignment, :settings, settings[assignment.resource_id])
    end)
  end

  defp get_completed_pages(section_id, current_user_id) do
    raw_completed_pages = Metrics.raw_completed_pages_for(section_id, current_user_id)

    %{
      completed_pages: Map.get(raw_completed_pages, current_user_id, 0),
      total_pages: Map.get(raw_completed_pages, :total_pages, 0)
    }
  end
end
