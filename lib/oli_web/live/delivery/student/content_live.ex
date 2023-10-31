defmodule OliWeb.Delivery.Student.ContentLive do
  use OliWeb, :live_view

  import OliWeb.Components.Delivery.Layouts

  alias OliWeb.Common.FormatDateTime
  alias Phoenix.LiveView.JS
  alias OliWeb.Components.Modal
  alias Oli.Delivery.{Metrics, Sections}
  alias OliWeb.Components.Delivery.Utils

  def mount(_params, _session, socket) do
    # TODO replace this with a call to the Cache data in ETS
    # (finally it will be stored as a json in a new section field maybe called "cached_hierarchy")
    hierarchy =
      Oli.Publishing.DeliveryResolver.full_hierarchy(socket.assigns.section.slug)

    # when updating to Liveview 0.20 we should replace this with assign_async/3
    # https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#assign_async/3
    if connected?(socket),
      do:
        async_calculate_student_metrics(
          self(),
          socket.assigns.section,
          socket.assigns.current_user.id
        )

    {:ok,
     assign(socket,
       hierarchy: hierarchy,
       selected_unit_uuid: nil,
       selected_module: nil,
       selected_module_index: nil,
       student_visited_pages: %{},
       student_progress_per_resource_id: %{}
     )}
  end

  def handle_event(
        "select_module",
        %{
          "unit_uuid" => unit_uuid,
          "module_uuid" => module_uuid,
          "module_index" => selected_module_index
        },
        socket
      ) do
    socket =
      if module_uuid == get_in(socket.assigns, [:selected_module, Access.key!(:uuid)]) do
        assign(socket, selected_unit_uuid: nil, selected_module: nil)
      else
        selected_module =
          get_module(socket.assigns.hierarchy, unit_uuid, module_uuid)
          |> mark_visited_pages(socket.assigns.student_visited_pages)

        assign(socket,
          selected_unit_uuid: unit_uuid,
          selected_module: selected_module,
          selected_module_index: selected_module_index
        )
      end
      |> push_event("scroll-to-target", %{id: "unit_#{unit_uuid}"})

    {:noreply, socket}
  end

  def handle_event("play_intro_video", %{"video_url" => _url}, socket) do
    # TODO play video
    {:noreply, socket}
  end

  def handle_event("navigate_to_resource", %{"slug" => resource_slug}, socket) do
    {:noreply,
     push_navigate(socket, to: resource_url(resource_slug, socket.assigns.section.slug))}
  end

  def handle_info(
        {:student_metrics, {student_visited_pages, student_progress_per_resource_id}},
        socket
      ) do
    {:noreply,
     assign(socket,
       student_visited_pages: student_visited_pages,
       student_progress_per_resource_id: student_progress_per_resource_id,
       selected_module:
         socket.assigns.selected_module &&
           mark_visited_pages(socket.assigns.selected_module, student_visited_pages)
     )}
  end

  # needed to ignore results of Task invocation
  def handle_info(_, socket), do: {:noreply, socket}

  def render(assigns) do
    ~H"""
    <Modal.modal id="video_player">
      <div class="h-[80vh]">imagine a video being played :)</div>
    </Modal.modal>
    <.header_with_sidebar_nav
      ctx={@ctx}
      section={@section}
      brand={@brand}
      preview_mode={@preview_mode}
      active_tab={:content}
    >
      <div id="student_content" class="container mx-auto p-[25px]" phx-hook="ScrollToTarget">
        <.unit
          :for={child <- @hierarchy.children}
          unit={child}
          section_start_date={@section.start_date}
          ctx={@ctx}
          unit_selected={child.uuid == @selected_unit_uuid}
          selected_module={@selected_module}
          selected_module_index={@selected_module_index}
          student_progress_per_resource_id={@student_progress_per_resource_id}
        />
      </div>
    </.header_with_sidebar_nav>
    """
  end

  attr :unit, :map
  attr :ctx, :map, doc: "the context is needed to format the date considering the user's timezone"
  attr :unit_selected, :boolean, default: false
  attr :selected_module, :map
  attr :selected_module_index, :string
  attr :section_start_date, :string, doc: "required to calculate the week number"
  attr :student_progress_per_resource_id, :map

  def unit(assigns) do
    # TODO: render real student progress for unit
    ~H"""
    <div id={"unit_#{@unit.uuid}"} class="p-[25px] pl-[50px]">
      <div class="mb-6 flex flex-col items-start gap-[6px]">
        <h3 class="text-[26px] leading-[32px] tracking-[0.02px] font-semibold ml-2">
          <%= "#{@unit.numbering.index}. #{@unit.revision.title}" %>
        </h3>
        <div class="flex items-center w-full">
          <div class="flex items-center gap-3 ">
            <div class="text-[14px] leading-[32px] tracking-[0.02px] font-semibold">
              <span class="text-gray-400 opacity-80">Week</span> <%= Utils.week_number(
                @section_start_date,
                @unit.section_resource.start_date
              ) %>
            </div>
            <div class="text-[14px] leading-[32px] tracking-[0.02px] font-semibold">
              <span class="text-gray-400 opacity-80">Complete by:</span> <%= parse_datetime(
                @unit.section_resource.end_date,
                @ctx
              ) %>
            </div>
          </div>
          <div class="ml-auto w-36">
            <.progress_bar
              percent={
                parse_student_progress_for_resource(
                  @student_progress_per_resource_id,
                  @unit.revision.resource_id
                )
              }
              width="100px"
            />
          </div>
        </div>
      </div>
      <div class="flex gap-4 overflow-x-auto overflow-y-hidden pt-[2px] pl-[2px] -mt-[2px] -ml-[2px]">
        <.intro_card
          :if={@unit.revision.intro_video || @unit.revision.poster_image}
          bg_image_url={@unit.revision.poster_image}
          video_url={@unit.revision.intro_video}
          on_play={
            Modal.show_modal("video_player")
            |> JS.push("play_intro_video", value: %{video_url: @unit.revision.intro_video})
          }
        />
        <.module_card
          :for={{module, module_index} <- Enum.with_index(@unit.children, 1)}
          module={module}
          module_index={module_index}
          unit_uuid={@unit.uuid}
          unit_numbering_index={@unit.numbering.index}
          bg_image_url={module.revision.poster_image}
          student_progress_per_resource_id={@student_progress_per_resource_id}
          selected={if @selected_module, do: module.uuid == @selected_module.uuid, else: false}
        />
      </div>
    </div>
    <div :if={@unit_selected} class="flex py-[24px] px-[50px] gap-x-4 lg:gap-x-12">
      <div class="w-1/2 flex flex-col px-6">
        <div class={[
          "intro-content",
          maybe_additional_margin_top(@selected_module.revision.intro_content["children"])
        ]}>
          <%= Phoenix.HTML.raw(
            Oli.Rendering.Content.render(
              %Oli.Rendering.Context{},
              @selected_module.revision.intro_content["children"],
              Oli.Rendering.Content.Html
            )
          ) %>
        </div>
        <button class="btn btn-primary mr-auto mt-[42px]">Let's discuss?</button>
      </div>
      <div class="mt-[62px] w-1/2">
        <.index module={@selected_module} module_index={@selected_module_index} />
        <p class="py-2 text-[14px] leading-[30px] font-normal"></p>
      </div>
    </div>
    """
  end

  attr :module, :map
  attr :module_index, :integer

  def index(assigns) do
    # TODO: render real check if student has visited the page
    ~H"""
    <div
      :for={{page, page_index} <- Enum.with_index(@module.children, 1)}
      class="flex gap-[14px] h-[42px] w-full"
    >
      <div class="flex justify-center items-center gap-[10px] h-6 w-6">
        <svg
          :if={page.visited}
          xmlns="http://www.w3.org/2000/svg"
          height="1.25em"
          viewBox="0 0 448 512"
        >
          <path
            fill="#1E9531"
            d="M438.6 105.4c12.5 12.5 12.5 32.8 0 45.3l-256 256c-12.5 12.5-32.8 12.5-45.3 0l-128-128c-12.5-12.5-12.5-32.8 0-45.3s32.8-12.5 45.3 0L160 338.7 393.4 105.4c12.5-12.5 32.8-12.5 45.3 0z"
          />
        </svg>
      </div>
      <div
        phx-click="navigate_to_resource"
        phx-value-slug={page.revision.slug}
        class="flex items-center gap-3 w-full border-b-2 border-gray-600 cursor-pointer hover:bg-gray-200/70 px-2"
      >
        <span class="text-[16px] leading-[22px] font-normal truncate">
          <%= "#{@module_index}.#{page_index} #{page.revision.title}" %>
        </span>
        <div class="flex items-center gap-[6px] ml-auto">
          <svg xmlns="http://www.w3.org/2000/svg" height="1.25em" viewBox="0 0 512 512">
            <path d="M464 256A208 208 0 1 1 48 256a208 208 0 1 1 416 0zM0 256a256 256 0 1 0 512 0A256 256 0 1 0 0 256zM232 120V256c0 8 4 15.5 10.7 20l96 64c11 7.4 25.9 4.4 33.3-6.7s4.4-25.9-6.7-33.3L280 243.2V120c0-13.3-10.7-24-24-24s-24 10.7-24 24z" />
          </svg>
          <span class="text-[12px] leading-[16px] font-bold uppercase tracking-[0.96px] w-[15px] text-right">
            <%= page.revision.duration_minutes %>
          </span>
          <span class="text-[12px] leading-[16px] font-bold uppercase tracking-[0.96px]">
            min
          </span>
        </div>
      </div>
    </div>
    """
  end

  attr :title, :string, default: "Intro"

  attr :video_url,
       :string,
       doc: "the video url is optional and, if provided, the play button will be rendered"

  attr :on_play, :any, doc: "the event to be triggered when the play button is clicked"
  attr :bg_image_url, :string, doc: "the background image url for the card"

  def intro_card(assigns) do
    ~H"""
    <div class="hover:scale-[1.01]">
      <div class={[
        "flex flex-col items-center rounded-lg h-[162px] w-[288px] bg-gray-200 shrink-0 px-5 pt-[15px]",
        if(@bg_image_url in ["", nil],
          do: "bg-[url('/images/course_default.jpg')]",
          else: "bg-[url('#{@bg_image_url}')]"
        )
      ]}>
        <h5 class="text-[13px] leading-[18px] font-bold self-start"><%= @title %></h5>
        <div :if={@video_url} phx-click={@on_play} class="w-[70px] h-[70px] relative my-auto -top-2">
          <div class="w-full h-full rounded-full backdrop-blur bg-gray/50"></div>
          <button class="w-full h-full absolute top-0 left-0 flex items-center justify-center">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="white"
              width="33"
              height="38"
              viewBox="0 0 16.984 24.8075"
              class="scale-110 ml-[6px] mt-[9px]"
            >
              <path d="M0.759,0.158c0.39-0.219,0.932-0.21,1.313,0.021l14.303,8.687c0.368,0.225,0.609,0.625,0.609,1.057   s-0.217,0.832-0.586,1.057L2.132,19.666c-0.382,0.231-0.984,0.24-1.375,0.021C0.367,19.468,0,19.056,0,18.608V1.237   C0,0.79,0.369,0.378,0.759,0.158z" />
            </svg>
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :module, :map
  attr :module_index, :integer
  attr :unit_numbering_index, :integer
  attr :unit_uuid, :string
  attr :selected, :boolean, default: false
  attr :bg_image_url, :string, doc: "the background image url for the card"
  attr :student_progress_per_resource_id, :map

  def module_card(assigns) do
    # TODO: render real student progress for module
    ~H"""
    <div class="hover:scale-[1.01] transition-transform duration-150">
      <div flex="h-[170px] w-[288px]">
        <div
          id={"module_#{@module.uuid}"}
          phx-click="select_module"
          phx-value-unit_uuid={@unit_uuid}
          phx-value-module_uuid={@module.uuid}
          phx-value-module_index={@module_index}
          class={[
            "flex flex-col gap-[5px] cursor-pointer rounded-xl h-[162px] w-[288px] shrink-0 mb-1 px-5 pt-[15px] bg-gray-200",
            if(@selected, do: "bg-gray-400 outline outline-2 outline-gray-800"),
            if(@bg_image_url in ["", nil],
              do: "bg-[url('/images/course_default.jpg')]",
              else: "bg-[url('#{@bg_image_url}')]"
            )
          ]}
        >
          <span class="text-[12px] leading-[16px] font-bold opacity-60 text-gray-500">
            <%= "#{@unit_numbering_index}.#{@module_index}" %>
          </span>
          <h5 class="text-[18px] leading-[25px] font-bold"><%= @module.revision.title %></h5>
          <div :if={!@selected} class="mt-auto flex h-[21px] justify-center items-center">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="10"
              height="5"
              viewBox="0 0 10 5"
              fill="currentColor"
            >
              <path d="M0 0L10 0L5 5Z" />
            </svg>
          </div>
        </div>
        <.progress_bar
          :if={!@selected}
          percent={
            parse_student_progress_for_resource(
              @student_progress_per_resource_id,
              @module.revision.resource_id
            )
          }
          width="60%"
          show_percent={false}
        />
        <div
          :if={@selected}
          class={[
            "flex justify-center items-center -mt-1"
          ]}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="27"
            height="12"
            viewBox="0 0 27 12"
            fill="currentColor"
          >
            <path d="M0 0L27 0L13.5 12Z" />
          </svg>
        </div>
      </div>
    </div>
    """
  end

  # Currently the intro_content for a revision does not support h1 tags. So,
  # if there is no <h1> tag in the content then we need to add an additional margin
  # to match the given figma design.
  defp maybe_additional_margin_top(content) do
    if !String.contains?(Jason.encode!(content), "\"type\":\"h1\""), do: "mt-[52px]"
  end

  defp parse_datetime(nil, _ctx), do: "not yet scheduled"

  defp parse_datetime(datetime, ctx) do
    datetime
    |> FormatDateTime.convert_datetime(ctx)
    |> Timex.format!("{WDshort} {Mshort} {D}, {YYYY}")
  end

  defp get_module(hierarchy, unit_uuid, module_uuid) do
    unit =
      Enum.find(hierarchy.children, fn unit ->
        unit.uuid == unit_uuid
      end)

    Enum.find(unit.children, fn module ->
      module.uuid == module_uuid
    end)
  end

  # TODO: for other courses with other hierarchy, the url might be a container url:
  # ~p"/sections/#{section_slug}/container/:revision_slug
  defp resource_url(resource_slug, section_slug) do
    ~p"/sections/#{section_slug}/page/#{resource_slug}"
  end

  defp get_student_metrics(section, current_user_id) do
    visited_pages_map = Sections.get_visited_pages(section.id, current_user_id)

    %{"container" => container_ids, "page" => page_ids} =
      Sections.get_resource_ids_group_by_resource_type(section.slug)

    progress_per_container_id =
      Metrics.progress_across(section.id, container_ids, current_user_id)
      |> Enum.into(%{}, fn {container_id, progress} ->
        {container_id, progress || 0.0}
      end)

    progress_per_page_id =
      Metrics.progress_across_for_pages(section.id, page_ids, [current_user_id])

    progress_per_resource_id = Map.merge(progress_per_page_id, progress_per_container_id)

    {visited_pages_map, progress_per_resource_id}
  end

  defp mark_visited_pages(module, visited_pages) do
    update_in(
      module,
      [Access.key!(:children)],
      &Enum.map(&1, fn page ->
        Map.put(page, :visited, Map.get(visited_pages, page.revision.id, false))
      end)
    )
  end

  defp parse_student_progress_for_resource(student_progress_per_resource_id, resource_id) do
    Map.get(student_progress_per_resource_id, resource_id, 0.0)
    |> Kernel.*(100)
    |> round()
    |> trunc()
  end

  defp async_calculate_student_metrics(liveview_pid, section, current_user_id) do
    Task.async(fn ->
      send(liveview_pid, {:student_metrics, get_student_metrics(section, current_user_id)})
    end)
  end
end
