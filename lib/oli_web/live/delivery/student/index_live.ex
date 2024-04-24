defmodule OliWeb.Delivery.Student.IndexLive do
  use OliWeb, :live_view

  import OliWeb.Components.Delivery.Layouts

  alias Oli.Delivery.{Attempts, Sections}
  alias Oli.Publishing.DeliveryResolver
  alias OliWeb.Components.Delivery.Schedule
  alias OliWeb.Delivery.Student.Utils

  def mount(_params, _session, socket) do
    section = socket.assigns[:section]
    current_user_id = socket.assigns[:current_user].id

    schedule_for_current_week =
      Sections.get_schedule_for_current_week(section, current_user_id)

    {:ok,
     assign(socket,
       active_tab: :index,
       schedule_for_current_week: schedule_for_current_week,
       section_slug: section.slug,
       historical_graded_attempt_summary: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <.header_banner ctx={@ctx} section_slug={@section_slug} />
    <div class="w-full h-96 relative bg-stone-950">
      <div class="w-full absolute p-8 justify-start items-start gap-6 inline-flex">
        <.course_progress />
        <div class="w-3/4 h-full flex-col justify-start items-start gap-6 inline-flex">
          <div class="w-full h-96 p-6 bg-gradient-to-b from-zinc-900 to-zinc-900 rounded-2xl justify-start items-start gap-32 inline-flex">
            <div class="flex-col justify-start items-start gap-7 inline-flex grow">
              <div class="justify-start items-start gap-2.5 inline-flex">
                <div class="text-white text-2xl font-bold leading-loose tracking-tight">
                  Upcoming Agenda
                </div>
              </div>
              <div class="justify-start items-center gap-1 inline-flex self-stretch">
                <div class="text-white text-base font-normal tracking-tight grow">
                  This week
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <%!-- <div class="container mx-auto">
      <div class="my-8 px-16">
        <div class="font-bold text-2xl mb-4">Up Next</div>

        <%= case @schedule_for_current_week do %>
          <% {week, schedule_ranges} -> %>
            <Schedule.week
              ctx={@ctx}
              week_number={week}
              show_border={false}
              schedule_ranges={schedule_ranges}
              section_slug={@section_slug}
              historical_graded_attempt_summary={@historical_graded_attempt_summary}
              request_path={~p"/sections/#{@section_slug}"}
            />
          <% _ -> %>
            <div class="text-xl">No schedule for this week.</div>
        <% end %>
      </div>
    </div> --%>
    """
  end

  attr(:ctx, :map, default: nil)
  attr(:section_slug, :string, required: true)

  defp header_banner(assigns) do
    ~H"""
    <div class="w-full h-96 relative flex items-center">
      <div class="inset-0 absolute">
        <img
          src="/images/gradients/home-bg.png"
          alt="Background Image"
          class="absolute inset-0 w-full h-full object-cover border border-black mix-blend-luminosity"
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
        <div id="pepe" class="w-full flex flex-col items-start gap-2.5">
          <div class="w-full whitespace-nowrap overflow-hidden">
            <span class="text-white text-3xl font-medium">
              Unlock the world of chemistry with <b>RealCHEM</b>
            </span>
          </div>
          <div class="w-4/12 text-white text-opacity-60 text-lg font-semibold">
            Dive in now and start shaping the future, one molecule at a time!
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

  defp course_progress(assigns) do
    ~H"""
    <div class="w-1/4 h-full flex-col justify-start items-start gap-6 inline-flex">
      <div class="w-full h-96 p-6 bg-gradient-to-b from-zinc-900 to-zinc-900 rounded-2xl justify-start items-start gap-32 inline-flex">
        <div class="flex-col justify-start items-start gap-7 inline-flex grow">
          <div class="justify-start items-start gap-2.5 inline-flex">
            <div class="text-white text-2xl font-bold leading-loose tracking-tight">
              Course Progress
            </div>
          </div>
          <div class="justify-start items-center gap-1 inline-flex self-stretch">
            <div class="text-white text-base font-normal tracking-tight grow">
              Begin your learning journey to watch your progress unfold here!
            </div>
          </div>
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
end
