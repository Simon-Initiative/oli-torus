defmodule OliWeb.Delivery.Student.IndexLive do
  use OliWeb, :live_view

  import OliWeb.Components.Delivery.Layouts

  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.{Attempts, Sections}
  alias Oli.Delivery.Sections.SectionCache
  alias Oli.Publishing.DeliveryResolver
  alias OliWeb.Components.Delivery.Schedule
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Delivery.Student.Utils

  import Ecto.Query, warn: false, only: [from: 2]

  def mount(_params, _session, socket) do
    section = socket.assigns[:section]
    current_user_id = socket.assigns[:current_user].id

    schedule_for_current_week =
      Sections.get_schedule_for_current_week(section, current_user_id)

    [last_open_and_unfinished_page, nearest_upcoming_lesson] =
      Enum.map(
        [
          Sections.get_last_open_and_unfinished_page(section, current_user_id),
          Sections.get_nearest_upcoming_lesson(section)
        ],
        fn page ->
          page_module_index =
            section
            |> get_or_compute_full_hierarchy()
            |> find_module_ancestor(
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
       schedule_for_current_week: schedule_for_current_week,
       section_slug: section.slug,
       historical_graded_attempt_summary: nil,
       has_visited_section: Sections.has_visited_section(section, socket.assigns[:current_user]),
       last_open_and_unfinished_page: last_open_and_unfinished_page,
       nearest_upcoming_lesson: nearest_upcoming_lesson
     )}
  end

  def render(assigns) do
    ~H"""
    <.header_banner
      ctx={@ctx}
      section_slug={@section_slug}
      has_visited_section={@has_visited_section}
      suggested_page={@last_open_and_unfinished_page || @nearest_upcoming_lesson}
      unfinished_lesson={!is_nil(@last_open_and_unfinished_page)}
    />
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

    <div class="container mx-auto">
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
    </div>
    """
  end

  attr(:ctx, :map, default: nil)
  attr(:section_slug, :string, required: true)
  attr(:has_visited_section, :boolean, required: true)
  attr(:suggested_page, :map)
  attr(:unfinished_lesson, :boolean, required: true)

  defp header_banner(%{has_visited_section: true} = assigns) do
    ~H"""
    <div class="w-full h-72 relative flex items-center">
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

      <div class="w-full px-9 absolute flex-col justify-center items-start gap-6 inline-flex">
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

  defp format_date("Not yet scheduled", _context, _format), do: "Not yet scheduled"

  defp format_date(due_date, context, format) do
    FormatDateTime.to_formatted_datetime(due_date, context, format)
  end

  defp find_module_ancestor(_, nil, _), do: nil

  defp find_module_ancestor(hierarchy, resource_id, container_resource_type_id) do
    case Oli.Delivery.Hierarchy.find_parent_in_hierarchy(
           hierarchy,
           &(&1["resource_id"] == resource_id)
         ) do
      %{"resource_type_id" => ^container_resource_type_id, "numbering" => %{"level" => 2}} =
          module ->
        module

      parent ->
        find_module_ancestor(hierarchy, parent["resource_id"], container_resource_type_id)
    end
  end

  def get_or_compute_full_hierarchy(section) do
    SectionCache.get_or_compute(section.slug, :full_hierarchy, fn ->
      full_hierarchy(section)
    end)
  end

  defp full_hierarchy(section) do
    {hierarchy_nodes, root_hierarchy_node} = hierarchy_nodes_by_sr_id(section)

    hierarchy_node_with_children(root_hierarchy_node, hierarchy_nodes)
  end

  defp hierarchy_node_with_children(
         %{"children" => children_ids} = node,
         nodes_by_sr_id
       ) do
    Map.put(
      node,
      "children",
      Enum.map(children_ids, fn sr_id ->
        Map.get(nodes_by_sr_id, sr_id)
        |> hierarchy_node_with_children(nodes_by_sr_id)
      end)
    )
  end

  # Returns a map of resource ids to hierarchy nodes and the root hierarchy node
  defp hierarchy_nodes_by_sr_id(section) do
    page_id = Oli.Resources.ResourceType.get_id_by_type("page")
    container_id = Oli.Resources.ResourceType.get_id_by_type("container")

    labels =
      case section.customizations do
        nil -> Oli.Branding.CustomLabels.default_map()
        l -> Map.from_struct(l)
      end

    from(
      [s: s, sr: sr, rev: rev, spp: spp] in DeliveryResolver.section_resource_revisions(
        section.slug
      ),
      join: p in Project,
      on: p.id == spp.project_id,
      where:
        rev.resource_type_id == ^page_id or
          rev.resource_type_id == ^container_id,
      select: %{
        "id" => rev.id,
        "numbering" => %{
          "index" => sr.numbering_index,
          "level" => sr.numbering_level
        },
        "children" => sr.children,
        "resource_id" => rev.resource_id,
        "project_id" => sr.project_id,
        "project_slug" => p.slug,
        "title" => rev.title,
        "slug" => rev.slug,
        "graded" => rev.graded,
        "intro_video" => rev.intro_video,
        "poster_image" => rev.poster_image,
        "intro_content" => rev.intro_content,
        "duration_minutes" => rev.duration_minutes,
        "resource_type_id" => rev.resource_type_id,
        "section_resource" => sr,
        "is_root?" =>
          fragment(
            "CASE WHEN ? = ? THEN true ELSE false END",
            sr.id,
            s.root_section_resource_id
          )
      }
    )
    |> Oli.Repo.all()
    |> Enum.map(fn node ->
      numbering = Map.put(node["numbering"], "labels", labels)

      Map.put(node, "uuid", Oli.Utils.uuid())
      |> Map.put("numbering", numbering)
    end)
    |> Enum.reduce({%{}, nil}, fn item, {nodes, root} ->
      {
        Map.put(
          nodes,
          item["section_resource"].id,
          item
        ),
        if(item["is_root?"], do: item, else: root)
      }
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
end
