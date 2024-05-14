defmodule OliWeb.Delivery.Student.IndexLive do
  use OliWeb, :live_view

  import OliWeb.Components.Delivery.Layouts

  alias Oli.Delivery.{Attempts, Hierarchy, Metrics, Sections}
  alias Oli.Delivery.Sections.SectionCache
  alias Oli.Publishing.DeliveryResolver
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Delivery.Student.Utils
  alias OliWeb.Delivery.Student.Home.Components.ScheduleComponent

  def mount(_params, _session, socket) do
    section = socket.assigns[:section]
    current_user_id = socket.assigns[:current_user].id

    schedule_for_current_week_and_next_week =
      Sections.get_schedule_for_current_and_next_week(section, current_user_id)

    # Use the root container revision to store the intro message for the course
    intro_message =
      section.slug
      |> DeliveryResolver.root_container()
      |> build_intro_message()

    [last_open_and_unfinished_page, nearest_upcoming_lesson] =
      Enum.map(
        [
          Sections.get_last_open_and_unfinished_page(section, current_user_id),
          Sections.get_nearest_upcoming_lesson(section)
        ],
        fn
          nil ->
            nil

          page ->
            page_module_index =
              section
              |> get_or_compute_full_hierarchy()
              |> Hierarchy.find_module_ancestor(
                page[:resource_id],
                Oli.Resources.ResourceType.get_id_by_type("container")
              )
              |> get_in(["numbering", "index"])

            Map.put(page, :module_index, page_module_index)
        end
      )

    {:ok,
     assign(socket,
       active_tab: :index,
       schedule_for_current_week_and_next_week: schedule_for_current_week_and_next_week,
       section_slug: section.slug,
       section_start_date: section.start_date,
       historical_graded_attempt_summary: nil,
       has_visited_section:
         Sections.has_visited_section(section, socket.assigns[:current_user],
           enrollment_state: false
         ),
       last_open_and_unfinished_page: last_open_and_unfinished_page,
       nearest_upcoming_lesson: nearest_upcoming_lesson,
       section_progress: section_progress(section.id, current_user_id),
       intro_message: intro_message
     )}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <.header_banner
      ctx={@ctx}
      section_slug={@section_slug}
      has_visited_section={@has_visited_section}
      suggested_page={@last_open_and_unfinished_page || @nearest_upcoming_lesson}
      unfinished_lesson={!is_nil(@last_open_and_unfinished_page)}
      intro_message={@intro_message}
    />
    <div class="w-full h-full relative bg-stone-950 dark:text-white">
      <div class="w-full absolute p-8 justify-start items-start gap-6 inline-flex">
        <.course_progress has_visited_section={@has_visited_section} progress={@section_progress} />
        <div class="w-3/4 h-full flex-col justify-start items-start gap-6 inline-flex">
          <div class="w-full h-fit overflow-y-auto p-6 bg-zinc-400 bg-opacity-20 rounded-2xl justify-start items-start gap-32 inline-flex">
            <div class="flex-col justify-start items-start gap-7 inline-flex grow">
              <div class="self-stretch justify-between items-baseline inline-flex gap-2.5">
                <div class="text-2xl font-bold leading-loose tracking-tight">
                  Upcoming Agenda
                </div>
                <.link
                  href={
                    Utils.schedule_live_path(
                      @section_slug,
                      request_path: ~p"/sections/#{@section_slug}"
                    )
                  }
                  class="hover:no-underline"
                >
                  <div class="text-blue-500 hover:text-blue-400 text-base font-bold tracking-tight">
                    View full schedule
                  </div>
                </.link>
              </div>
              <.live_component
                module={ScheduleComponent}
                ctx={@ctx}
                id="schedule_component"
                schedule_for_current_week_and_next_week={@schedule_for_current_week_and_next_week}
                section_start_date={@section_start_date}
                section_slug={@section_slug}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr(:ctx, :map, default: nil)
  attr(:section_slug, :string, required: true)
  attr(:has_visited_section, :boolean, required: true)
  attr(:suggested_page, :map)
  attr(:unfinished_lesson, :boolean, required: true)
  attr(:intro_message, :map)

  defp header_banner(%{has_visited_section: true} = assigns) do
    ~H"""
    <div class="w-full h-72 relative flex items-center">
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
        class="w-full px-9 absolute flex-col justify-center items-start gap-6 inline-flex"
      >
        <div class="text-white text-2xl font-bold leading-loose tracking-tight">
          Continue Learning
        </div>
        <div class="self-stretch p-6 bg-zinc-900 bg-opacity-40 rounded-xl justify-between items-end inline-flex">
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
              <div class="grow shrink basis-0 h-5 justify-start items-center gap-1 flex">
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
                  <div class="text-white text-lg font-semibold">
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
          <div class="justify-start items-start gap-3.5 flex">
            <.link
              href={
                Utils.lesson_live_path(
                  @section_slug,
                  @suggested_page.slug,
                  request_path: ~p"/sections/#{@section_slug}"
                )
              }
              class="hover:no-underline"
            >
              <div class="w-full h-10 px-5 py-2.5 bg-blue-600 rounded-lg shadow justify-center items-center gap-2.5 flex hover:bg-blue-500">
                <div class="text-white text-sm font-bold leading-tight">
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
              class="hover:no-underline"
            >
              <div class="w-44 h-10 px-5 py-2.5 bg-white bg-opacity-20 rounded-lg shadow justify-center items-center gap-2.5 flex hover:bg-opacity-40">
                <div class="text-white text-sm font-semibold leading-tight">
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
    <div class="w-full h-96 relative flex items-center">
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

      <div class="w-full pl-14 pr-5 absolute flex flex-col justify-center items-start gap-6">
        <div class="w-full text-white text-2xl font-bold tracking-wide whitespace-nowrap overflow-hidden">
          Hi, <%= user_given_name(@ctx) %> !
        </div>
        <div class="w-full flex flex-col items-start gap-2.5">
          <div class="w-full whitespace-nowrap overflow-hidden">
            <span class="text-3xl font-medium">
              <%= @intro_message %>
            </span>
          </div>
        </div>
        <div class="pt-5 flex items-start gap-6">
          <.link
            href={
              Utils.lesson_live_path(
                @section_slug,
                DeliveryResolver.get_first_page_slug(@section_slug),
                request_path: ~p"/sections/#{@section_slug}"
              )
            }
            class="hover:no-underline"
          >
            <div class="w-52 h-11 px-5 py-2.5 bg-blue-600 rounded-lg shadow flex justify-center items-center gap-2.5 hover:bg-blue-500">
              <div class="text-white text-base font-bold leading-tight">
                Start course
              </div>
            </div>
          </.link>
          <.link href={Utils.learn_live_path(@section_slug)} class="hover:no-underline">
            <div class="w-52 h-11 px-5 py-2.5 bg-white bg-opacity-20 rounded-lg shadow flex justify-center items-center gap-2.5 hover:bg-opacity-40">
              <div class="text-white text-base font-semibold leading-tight">
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
  attr(:progress, :integer, required: true)

  defp course_progress(assigns) do
    ~H"""
    <div class="w-1/4 h-48 flex-col justify-start items-start gap-6 inline-flex">
      <div class="w-full h-96 p-6 bg-zinc-400 bg-opacity-20 rounded-2xl justify-start items-start gap-32 inline-flex">
        <div class="flex-col justify-start items-start gap-5 inline-flex grow">
          <div class="justify-start items-start gap-2.5 inline-flex">
            <div class="text-2xl font-bold leading-loose tracking-tight">
              Course Progress
            </div>
          </div>
          <%= if @has_visited_section do %>
            <div class="flex-col justify-start items-start flex">
              <div>
                <span class="text-6xl font-bold tracking-wide"><%= @progress %></span>
                <span class="text-3xl font-bold tracking-tight">%</span>
              </div>
            </div>
          <% else %>
            <div class="justify-start items-center gap-1 inline-flex self-stretch">
              <div class="text-base font-normal tracking-tight grow">
                Begin your learning journey to watch your progress unfold here!
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
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

  defp format_date("Not yet scheduled", _context, _format), do: "Not yet scheduled"

  defp format_date(due_date, context, format) do
    FormatDateTime.to_formatted_datetime(due_date, context, format)
  end

  def get_or_compute_full_hierarchy(section) do
    SectionCache.get_or_compute(section.slug, :full_hierarchy, fn ->
      Hierarchy.full_hierarchy(section)
    end)
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

  defp section_progress(section_id, user_id) do
    Metrics.progress_for(section_id, user_id)
    |> Kernel.*(100)
    |> round()
    |> trunc()
  end

  defp build_intro_message(%{intro_content: intro_content}) when intro_content not in [nil, %{}],
    do:
      Phoenix.HTML.raw(
        Oli.Rendering.Content.render(
          %Oli.Rendering.Context{},
          intro_content["children"],
          Oli.Rendering.Content.Html
        )
      )

  defp build_intro_message(_), do: "Welcome to this course!"
end
