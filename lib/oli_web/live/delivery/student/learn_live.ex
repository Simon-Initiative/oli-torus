defmodule OliWeb.Delivery.Student.LearnLive do
  use OliWeb, :live_view

  alias Oli.Accounts.{User}
  alias OliWeb.Common.FormatDateTime
  alias Oli.Delivery.{Metrics, Sections}
  alias Phoenix.LiveView.JS

  # TODO
  # bug in module index when collapsing and expanding many cards
  # mark video as viewed at student enrollment level (in the state field)
  # introduction and learning objectives at module index. intro corresponds to intro_content revision field for the module
  # 15 / 20 at unit level (when completed)

  def mount(_params, _session, socket) do
    # when updating to Liveview 0.20 we should replace this with assign_async/3
    # https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#assign_async/3
    if connected?(socket),
      do:
        async_calculate_student_metrics_and_enable_slider_buttons(
          self(),
          socket.assigns.section,
          socket.assigns[:current_user]
        )

    {:ok,
     assign(socket,
       active_tab: :learn,
       selected_module_per_unit_uuid: %{},
       student_visited_pages: %{},
       student_progress_per_resource_id: %{},
       student_raw_avg_score_per_page_id: %{}
     )}
  end

  def handle_event("open_dot_bot", _, socket) do
    # TODO: this button should open DOT bot when implemented here.
    {:noreply, socket}
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
    current_selected_module_for_unit =
      Map.get(socket.assigns.selected_module_per_unit_uuid, unit_uuid)

    {selected_module_per_unit_uuid, expand_module?} =
      case current_selected_module_for_unit do
        nil ->
          {Map.merge(socket.assigns.selected_module_per_unit_uuid, %{
             unit_uuid =>
               get_module(
                 Sections.get_full_hierarchy(socket.assigns.section),
                 unit_uuid,
                 module_uuid
               )
               |> mark_visited_pages(socket.assigns.student_visited_pages)
               |> Map.merge(%{"module_index_in_unit" => selected_module_index})
           }), true}

        current_module ->
          clicked_module =
            get_module(
              Sections.get_full_hierarchy(socket.assigns.section),
              unit_uuid,
              module_uuid
            )

          if clicked_module["uuid"] == current_module["uuid"] do
            # if the user clicked in an already expanded module, then we should collapse it
            {Map.drop(
               socket.assigns.selected_module_per_unit_uuid,
               [unit_uuid]
             ), false}
          else
            {Map.merge(socket.assigns.selected_module_per_unit_uuid, %{
               unit_uuid =>
                 mark_visited_pages(clicked_module, socket.assigns.student_visited_pages)
                 |> Map.merge(%{"module_index_in_unit" => selected_module_index})
             }), true}
          end
      end

    {:noreply,
     socket
     |> assign(selected_module_per_unit_uuid: selected_module_per_unit_uuid)
     |> maybe_scroll_y_to_unit(unit_uuid, expand_module?)
     |> push_event("hide-or-show-buttons-on-sliders", %{
       unit_uuids:
         Enum.map(Sections.get_full_hierarchy(socket.assigns.section)["children"], & &1["uuid"])
     })
     |> push_event("js-exec", %{
       to: "#selected_module_in_unit_#{unit_uuid}",
       attr: "data-animate"
     })}
  end

  def handle_event("navigate_to_resource", %{"slug" => resource_slug}, socket) do
    {:noreply,
     push_navigate(socket, to: resource_url(resource_slug, socket.assigns.section.slug))}
  end

  def handle_info(
        {:student_metrics_and_enable_slider_buttons, nil},
        socket
      ) do
    {:noreply, socket}
  end

  def handle_info(
        {:student_metrics_and_enable_slider_buttons,
         {student_visited_pages, student_progress_per_resource_id,
          student_raw_avg_score_per_page_id}},
        socket
      ) do
    {:noreply,
     assign(socket,
       student_visited_pages: student_visited_pages,
       student_progress_per_resource_id: student_progress_per_resource_id,
       student_raw_avg_score_per_page_id: student_raw_avg_score_per_page_id,
       selected_module_per_unit_uuid:
         Enum.into(
           socket.assigns.selected_module_per_unit_uuid,
           %{},
           fn {unit_uuid, selected_module} ->
             {unit_uuid, mark_visited_pages(selected_module, student_visited_pages)}
           end
         )
     )
     |> push_event("enable-slider-buttons", %{
       unit_uuids:
         Enum.map(Sections.get_full_hierarchy(socket.assigns.section)["children"], & &1["uuid"])
     })}
  end

  # needed to ignore results of Task invocation
  def handle_info(_, socket), do: {:noreply, socket}

  def render(assigns) do
    ~H"""
    <div id="student_learn" class="lg:container lg:mx-auto p-[25px]" phx-hook="Scroller">
      <.unit
        :for={unit <- Sections.get_full_hierarchy(@section)["children"]}
        unit={unit}
        ctx={@ctx}
        student_progress_per_resource_id={@student_progress_per_resource_id}
        selected_module_per_unit_uuid={@selected_module_per_unit_uuid}
        student_raw_avg_score_per_page_id={@student_raw_avg_score_per_page_id}
        progress={
          parse_student_progress_for_resource(
            @student_progress_per_resource_id,
            unit["revision"]["resource_id"]
          )
        }
        student_id={@current_user.id}
      />
    </div>
    """
  end

  attr :unit, :map
  attr :ctx, :map, doc: "the context is needed to format the date considering the user's timezone"
  attr :student_progress_per_resource_id, :map
  attr :student_raw_avg_score_per_page_id, :map
  attr :selected_module_per_unit_uuid, :map
  attr :progress, :integer
  attr :student_id, :integer

  def unit(assigns) do
    ~H"""
    <div
      id={"unit_#{@unit["uuid"]}"}
      class="p-[25px] pl-[50px]"
      role={"unit_#{@unit["numbering"]["index"]}"}
    >
      <div class="flex gap-[30px]">
        <div class="text-[14px] leading-[19px] tracking-[1.4px] uppercase mt-[7px] whitespace-nowrap opacity-60">
          <%= "UNIT #{@unit["numbering"]["index"]}" %>
        </div>
        <div class="mb-6 flex flex-col items-start gap-[6px] w-full">
          <h3 class="text-[26px] leading-[32px] tracking-[0.02px] font-normal dark:text-[#DDD]">
            <%= @unit["revision"]["title"] %>
          </h3>
          <div class="flex items-center w-full">
            <div class="flex items-center gap-3" role="schedule_details">
              <div class="text-[14px] leading-[32px] tracking-[0.02px] font-semibold">
                <span class="text-gray-400 opacity-80 dark:text-[#696974] dark:opacity-100 mr-1">
                  Due:
                </span>
                <%= to_formatted_datetime(
                  @unit["section_resource"]["end_date"],
                  @ctx,
                  "{WDshort}, {Mshort} {D}, {YYYY} ({h12}:{m}{am})"
                ) %>
              </div>
            </div>
            <div class="ml-auto flex items-center gap-6">
              <.progress_bar
                percent={@progress}
                width="100px"
                on_going_colour="bg-[#0F6CF5]"
                completed_colour="bg-[#0CAF61]"
                role={"unit_#{@unit["numbering"]["index"]}_progress"}
                show_percent={@progress != 100}
              />
              <svg
                :if={@progress == 100}
                xmlns="http://www.w3.org/2000/svg"
                width="25"
                height="24"
                viewBox="0 0 25 24"
                fill="none"
              >
                <path
                  d="M10.0496 17.9996L4.34961 12.2996L5.77461 10.8746L10.0496 15.1496L19.2246 5.97461L20.6496 7.39961L10.0496 17.9996Z"
                  fill="#0CAF61"
                />
              </svg>
            </div>
          </div>
        </div>
      </div>
      <div class="flex relative">
        <button
          id={"slider_left_button_#{@unit["uuid"]}"}
          class="hidden absolute items-center justify-start -top-1 -left-1 w-10 bg-gradient-to-r from-gray-100 dark:from-gray-900 h-[180px] z-20 text-gray-400 hover:text-gray-700 dark:text-gray-600 hover:text-xl hover:dark:text-gray-200 hover:w-16 cursor-pointer"
        >
          <i class="fa-solid fa-chevron-left ml-3"></i>
        </button>
        <button
          id={"slider_right_button_#{@unit["uuid"]}"}
          class="hidden absolute items-center justify-end -top-1 -right-1 w-10 bg-gradient-to-l from-gray-100 dark:from-gray-900 h-[180px] z-20 text-gray-400 hover:text-gray-700 dark:text-gray-600 hover:text-xl hover:dark:text-gray-200 hover:w-16 cursor-pointer"
        >
          <i class="fa-solid fa-chevron-right mr-3"></i>
        </button>
        <div
          id={"slider_#{@unit["uuid"]}"}
          role="slider"
          phx-hook="SliderScroll"
          data-uuid={@unit["uuid"]}
          class="flex gap-4 overflow-x-scroll overflow-y-hidden h-[178px] pt-[3px] px-[3px] scrollbar-hide"
        >
          <.intro_card
            :if={@unit["revision"]["intro_video"] || @unit["revision"]["poster_image"]}
            bg_image_url={@unit["revision"]["poster_image"]}
            video_url={@unit["revision"]["intro_video"]}
            card_uuid={@unit["uuid"]}
          />
          <.module_card
            :for={{module, module_index} <- Enum.with_index(@unit["children"], 1)}
            module={module}
            module_index={module_index}
            unit_uuid={@unit["uuid"]}
            unit_numbering_index={@unit["numbering"]["index"]}
            bg_image_url={module["revision"]["poster_image"]}
            student_progress_per_resource_id={@student_progress_per_resource_id}
            selected={@selected_module_per_unit_uuid["#{@unit["uuid"]}"]["uuid"] == module["uuid"]}
          />
        </div>
      </div>
    </div>
    <div
      :if={Map.has_key?(@selected_module_per_unit_uuid, @unit["uuid"])}
      class="flex-col py-6 px-[50px] gap-x-4 lg:gap-x-12 gap-y-6"
      role="module_details"
      id={"selected_module_in_unit_#{@unit["uuid"]}"}
      data-animate={
        JS.show(
          to: "#selected_module_in_unit_#{@unit["uuid"]}",
          display: "flex",
          transition: {"ease-out duration-1000", "opacity-0", "opacity-100"}
        )
      }
    >
      <div role="expanded module header" class="flex flex-col gap-[8px] items-center">
        <h2 class="text-[26px] leading-[32px] tracking-[0.02px] dark:text-white">
          <%= Map.get(@selected_module_per_unit_uuid, @unit["uuid"])["revision"]["title"] %>
        </h2>
        <span class="text-[12px] leading-[16px] opacity-50 dark:text-white">
          Due: <%= to_formatted_datetime(
            Map.get(@selected_module_per_unit_uuid, @unit["uuid"])["section_resource"]["end_date"],
            @ctx,
            "{WDshort} {Mshort} {D}, {YYYY}"
          ) %>
        </span>
      </div>
      <div role="intro content and index" class="flex gap-12">
        <div class="w-1/2 flex flex-col">
          <div
            :if={
              Map.get(@selected_module_per_unit_uuid, @unit["uuid"])["revision"]["intro_content"][
                "children"
              ]
            }
            class={[
              "intro-content",
              maybe_additional_margin_top(
                Map.get(@selected_module_per_unit_uuid, @unit["uuid"])["revision"]["intro_content"][
                  "children"
                ]
              )
            ]}
          >
            <%= Phoenix.HTML.raw(
              Oli.Rendering.Content.render(
                %Oli.Rendering.Context{},
                Map.get(@selected_module_per_unit_uuid, @unit["uuid"])["revision"]["intro_content"][
                  "children"
                ],
                Oli.Rendering.Content.Html
              )
            ) %>
          </div>
          <button
            phx-click="open_dot_bot"
            class="rounded-[4px] p-[10px] flex justify-center items-center ml-auto mt-[42px] text-[14px] leading-[19px] tracking-[0.024px] font-normal text-white bg-blue-500 hover:bg-blue-600 dark:text-white dark:bg-[rgba(255,255,255,0.10);] dark:hover:bg-gray-800"
          >
            Let's discuss?
          </button>
        </div>
        <div class="mt-[57px] w-1/2">
          <.module_index
            module={Map.get(@selected_module_per_unit_uuid, @unit["uuid"])}
            student_raw_avg_score_per_page_id={@student_raw_avg_score_per_page_id}
            ctx={@ctx}
            student_id={@student_id}
          />
        </div>
      </div>
      <div role="collapse_bar" class="flex items-center justify-center py-[6px] px-[10px] mt-6">
        <span class="w-1/2 rounded-lg h-[2px] bg-gray-600/10 dark:bg-[#D9D9D9] dark:bg-opacity-10">
        </span>
        <div class="text-gray-600/10 dark:text-[#D9D9D9] dark:text-opacity-10 flex items-center justify-center px-[44px]">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="12"
            height="6"
            viewBox="0 0 12 6"
            fill="currentColor"
            role="up_arrow"
          >
            <path d="M6 0L0 6H12L6 0Z" fill="currentColor" />
          </svg>
        </div>
        <span class="w-1/2 rounded-lg h-[2px] bg-gray-600/10 dark:bg-[#D9D9D9] dark:bg-opacity-10">
        </span>
      </div>
    </div>
    """
  end

  attr :module, :map
  attr :student_raw_avg_score_per_page_id, :map
  attr :ctx, :map
  attr :student_id, :integer

  def module_index(assigns) do
    ~H"""
    <video
      :if={module_has_intro_video(@module)}
      id={"video_#{@module["uuid"]}"}
      class="hidden"
      controls
    >
      <source src={@module["revision"]["intro_video"]} type="video/mp4" />
      Your browser does not support the video tag.
    </video>
    <div class="flex flex-col gap-[6px] items-start">
      <.index_item
        :if={module_has_intro_video(@module)}
        title="Introduction"
        type="intro"
        numbering_index={1}
        was_visited={false}
        graded={@module["revision"]["graded"]}
        duration_minutes={@module["revision"]["duration_minutes"]}
        revision_slug={@module["revision"]["slug"]}
        uuid={@module["uuid"]}
        raw_avg_score={%{}}
      />

      <.index_item
        :for={
          {page, page_index} <-
            Enum.with_index(@module["children"], if(module_has_intro_video(@module), do: 2, else: 1))
        }
        title={page["revision"]["title"]}
        type="page"
        numbering_index={page_index}
        was_visited={page["visited"]}
        duration_minutes={page["revision"]["duration_minutes"]}
        graded={page["revision"]["graded"]}
        revision_slug={page["revision"]["slug"]}
        uuid={@module["uuid"]}
        due_date={
          if page["revision"]["graded"],
            do:
              get_due_date_for_student(
                page["section_resource"]["end_date"],
                page["revision"]["resource_id"],
                page["section_resource"]["section_id"],
                @student_id,
                @ctx,
                "{WDshort} {Mshort} {D}, {YYYY}"
              )
        }
        raw_avg_score={Map.get(@student_raw_avg_score_per_page_id, page["revision"]["resource_id"])}
      />
    </div>
    """
  end

  attr :title, :string
  attr :type, :string
  attr :numbering_index, :integer
  attr :was_visited, :boolean
  attr :duration_minutes, :integer
  attr :revision_slug, :string
  attr :graded, :boolean
  attr :uuid, :string
  attr :raw_avg_score, :map
  attr :due_date, :string

  def index_item(assigns) do
    ~H"""
    <div
      role={"page_#{@numbering_index}_details"}
      class="flex items-center gap-[14px] px-[10px] w-full"
    >
      <.index_item_icon
        item_type={@type}
        was_visited={@was_visited}
        graded={@graded}
        raw_avg_score={@raw_avg_score[:score]}
      />
      <div
        id={@uuid}
        phx-click={if @type != "intro", do: "navigate_to_resource"}
        phx-hook={if @type == "intro", do: "VideoPlayer"}
        phx-value-slug={@revision_slug}
        class="flex shrink items-center gap-3 w-full px-2 dark:text-white cursor-pointer hover:bg-gray-200/70 dark:hover:bg-gray-800"
      >
        <span class="text-[12px] leading-[16px] font-bold w-[30px] shrink-0 opacity-40 dark:text-white">
          <%= "#{@numbering_index}" %>
        </span>
        <div class="flex flex-col gap-1 w-full">
          <div class="flex">
            <span class={[
              "text-[16px] leading-[22px] dark:text-white",
              if(@was_visited, do: "opacity-50")
            ]}>
              <%= "#{@title}" %>
            </span>

            <div class="text-right dark:text-white opacity-50 whitespace-nowrap ml-auto">
              <span class="text-[12px] leading-[16px] font-bold uppercase tracking-[0.96px] text-right">
                <%= parse_minutes(@duration_minutes) %>
                <span class="text-[9px] font-bold uppercase tracking-[0.72px] text-right">
                  min
                </span>
              </span>
            </div>
          </div>
          <div :if={@graded} role="due date and score" class="flex">
            <span class="text-[12px] leading-[16px] opacity-50 dark:text-white">
              Due: <%= @due_date %>
            </span>
            <div :if={@raw_avg_score[:score]} class="flex items-center gap-[6px] ml-auto">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 16 16"
                fill="none"
              >
                <path
                  d="M3.88301 14.0007L4.96634 9.31732L1.33301 6.16732L6.13301 5.75065L7.99967 1.33398L9.86634 5.75065L14.6663 6.16732L11.033 9.31732L12.1163 14.0007L7.99967 11.5173L3.88301 14.0007Z"
                  fill="#0CAF61"
                />
              </svg>
              <span class="text-[12px] leading-[16px] tracking-[0.02px] text-[#0CAF61] font-semibold">
                <%= @raw_avg_score[:score] %> / <%= @raw_avg_score[:out_of] %>
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :item_type, :string
  attr :was_visited, :boolean
  attr :graded, :boolean
  attr :raw_avg_score, :map

  def index_item_icon(assigns) do
    case {assigns.was_visited, assigns.item_type, assigns.graded, assigns.raw_avg_score} do
      {true, "page", false, _} ->
        # visited practice page
        ~H"""
        <div role="check icon" class="flex justify-center items-center h-7 w-7 shrink-0">
          <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
            <path
              d="M9.54961 17.9996L3.84961 12.2996L5.27461 10.8746L9.54961 15.1496L18.7246 5.97461L20.1496 7.39961L9.54961 17.9996Z"
              fill="#0CAF61"
            />
          </svg>
        </div>
        """

      {false, "page", false, _} ->
        # not visited practice page
        ~H"""
        <div role="no icon" class="flex justify-center items-center h-7 w-7 shrink-0"></div>
        """

      {true, "page", true, raw_avg_score} when not is_nil(raw_avg_score) ->
        # completed graded page
        ~H"""
        <div role="square check icon" class="flex justify-center items-center h-7 w-7 shrink-0">
          <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
            <path
              d="M5 21C4.45 21 3.97917 20.8042 3.5875 20.4125C3.19583 20.0208 3 19.55 3 19V5C3 4.45 3.19583 3.97917 3.5875 3.5875C3.97917 3.19583 4.45 3 5 3H17.925L15.925 5H5V19H19V12.05L21 10.05V19C21 19.55 20.8042 20.0208 20.4125 20.4125C20.0208 20.8042 19.55 21 19 21H5Z"
              fill="#0CAF61"
            />
            <path
              d="M11.7 16.025L6 10.325L7.425 8.9L11.7 13.175L20.875 4L22.3 5.425L11.7 16.025Z"
              fill="#0CAF61"
            />
          </svg>
        </div>
        """

      {_, "page", true, nil} ->
        # not completed graded page
        ~H"""
        <div role="orange flag icon" class="flex justify-center items-center h-7 w-7 shrink-0">
          <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
            <path d="M5 21V4H14L14.4 6H20V16H13L12.6 14H7V21H5Z" fill="#F68E2E" />
          </svg>
        </div>
        """

      {_, "intro", _, _} ->
        # intro video
        ~H"""
        <div role="video icon" class="flex justify-center items-center h-7 w-7 shrink-0">
          <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
            <path
              opacity="0.5"
              d="M9.5 16.5L16.5 12L9.5 7.5V16.5ZM4 20C3.45 20 2.97917 19.8042 2.5875 19.4125C2.19583 19.0208 2 18.55 2 18V6C2 5.45 2.19583 4.97917 2.5875 4.5875C2.97917 4.19583 3.45 4 4 4H20C20.55 4 21.0208 4.19583 21.4125 4.5875C21.8042 4.97917 22 5.45 22 6V18C22 18.55 21.8042 19.0208 21.4125 19.4125C21.0208 19.8042 20.55 20 20 20H4Z"
              fill="#0CAF61"
            />
          </svg>
        </div>
        """
    end
  end

  attr :title, :string, default: "Intro"

  attr :video_url,
       :string,
       doc: "the video url is optional and, if provided, the play button will be rendered"

  attr :bg_image_url, :string, doc: "the background image url for the card"
  attr :card_uuid, :string

  def intro_card(assigns) do
    ~H"""
    <div class="relative slider-card hover:scale-[1.01]" role="intro_card">
      <div class="rounded-lg absolute -top-[0.7px] -left-[0.7px] h-[163px] w-[289.5px] cursor-pointer bg-[linear-gradient(180deg,#D9D9D9_0%,rgba(217,217,217,0.00)_100%)] dark:bg-[linear-gradient(180deg,#223_0%,rgba(34,34,51,0.72)_52.6%,rgba(34,34,51,0.00)_100%)]" />
      <div class={[
        "flex flex-col items-center rounded-lg h-[162px] w-[288px] bg-gray-200/50 shrink-0 px-5 pt-[15px]",
        if(@bg_image_url in ["", nil],
          do: "bg-[url('/images/course_default.jpg')]",
          else: "bg-[url('#{@bg_image_url}')]"
        )
      ]}>
        <h5 class="text-[13px] leading-[18px] font-bold opacity-60 text-gray-500 dark:text-white dark:text-opacity-50 self-start">
          <%= @title %>
        </h5>
        <div
          :if={@video_url}
          id={@card_uuid}
          phx-hook="VideoPlayer"
          class="w-[70px] h-[70px] relative my-auto -top-2 cursor-pointer"
        >
          <div class="w-full h-full rounded-full backdrop-blur bg-gray/50"></div>
          <button
            role="play_unit_intro_video"
            class="w-full h-full absolute top-0 left-0 flex items-center justify-center"
          >
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
          <video id={"video_#{@card_uuid}"} class="hidden" controls>
            <source src={@video_url} type="video/mp4" /> Your browser does not support the video tag.
          </video>
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
    ~H"""
    <div
      id={"module_#{@module["uuid"]}"}
      phx-click={
        if is_page(@module["revision"]),
          do: "navigate_to_resource",
          else:
            JS.hide(
              to: "#selected_module_in_unit_#{@unit_uuid}",
              transition: {"ease-out duration-500", "opacity-100", "opacity-0"}
            )
            |> JS.push("select_module")
      }
      phx-value-unit_uuid={@unit_uuid}
      phx-value-module_uuid={@module["uuid"]}
      phx-value-slug={@module["revision"]["slug"]}
      phx-value-module_index={@module_index}
      class={[
        "relative hover:scale-[1.01] transition-transform duration-150",
        if(!is_page(@module["revision"]), do: "slider-card")
      ]}
      role={"card_#{@module_index}"}
    >
      <div class="rounded-xl overflow-hidden absolute h-[163px] w-[288px] cursor-pointer bg-[linear-gradient(180deg,#D9D9D9_0%,rgba(217,217,217,0.00)_100%)] dark:bg-[linear-gradient(180deg,#223_0%,rgba(34,34,51,0.72)_52.6%,rgba(34,34,51,0.00)_100%)]">
        <.progress_bar
          :if={!is_page(@module["revision"])}
          percent={
            parse_student_progress_for_resource(
              @student_progress_per_resource_id,
              @module["revision"]["resource_id"]
            )
          }
          width="100%"
          height="h-[4px]"
          show_percent={false}
          on_going_colour="bg-[#0F6CF5]"
          completed_colour="bg-[#0CAF61]"
          role={"card_#{@module_index}_progress"}
        />
      </div>
      <.page_icon :if={is_page(@module["revision"])} graded={@module["revision"]["graded"]} />

      <div class="h-[170px] w-[288px]">
        <div class={[
          "flex flex-col gap-[5px] cursor-pointer rounded-xl h-[162px] w-[288px] shrink-0 mb-1 px-5 pt-[15px] bg-gray-200 z-10",
          if(@selected,
            do: "bg-gray-400 outline outline-2 outline-gray-800 dark:outline-white"
          ),
          if(@bg_image_url in ["", nil],
            do: "bg-[url('/images/course_default.jpg')]",
            else: "bg-[url('#{@bg_image_url}')]"
          )
        ]}>
          <span class="text-[12px] leading-[16px] font-bold opacity-60 text-gray-500 dark:text-white dark:text-opacity-50">
            <%= "#{@unit_numbering_index}.#{@module_index}" %>
          </span>
          <h5 class="text-[18px] leading-[25px] font-bold dark:text-white z-10">
            <%= @module["revision"]["title"] %>
          </h5>
        </div>

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

  attr :graded, :boolean

  def page_icon(assigns) do
    if assigns.graded do
      ~H"""
      <div
        class="h-[36px] w-[36px] absolute top-0 right-0 bg-[#F68E2E] rounded-bl-xl rounded-tr-xl"
        role="graded page icon"
      >
        <div class="absolute top-0 right-0 h-[36px] w-[36px] flex justify-center items-center">
          <svg xmlns="http://www.w3.org/2000/svg" width="25" height="24" viewBox="0 0 25 24" fill="none">
            <path d="M5.5 21V4H14.5L14.9 6H20.5V16H13.5L13.1 14H7.5V21H5.5Z" fill="white" />
          </svg>
        </div>
      </div>
      """
    else
      ~H"""
      <div class="h-[45px] w-[36px] absolute top-0 right-0" role="page icon">
        <img src={~p"/images/course_content/page_icon.png"} />
        <div class="absolute top-0 right-0 h-[36px] w-[36px] flex justify-center items-center">
          <svg xmlns="http://www.w3.org/2000/svg" width="18" height="20" viewBox="0 0 18 20" fill="none">
            <path
              d="M3.34359 15.9558C2.54817 15.1604 1.89985 14.3023 1.39862 13.3816C0.897394 12.4608 0.537819 11.5183 0.319895 10.554C0.107418 9.58968 0.0338689 8.64171 0.0992462 7.71008C0.170072 6.77846 0.382548 5.90131 0.736675 5.07865C1.09625 4.25053 1.59203 3.51776 2.22401 2.88034C2.88323 2.22111 3.63507 1.71989 4.47952 1.37666C5.32943 1.03343 6.22292 0.842744 7.15999 0.804607C8.09707 0.761023 9.03414 0.864537 9.97122 1.11515C10.9083 1.36576 11.7963 1.75258 12.6353 2.2756L11.2216 3.66486C10.6223 3.34342 9.97939 3.10098 9.29293 2.93754C8.61191 2.76865 7.92545 2.69782 7.23354 2.72506C6.54708 2.74686 5.88786 2.88034 5.25588 3.1255C4.62935 3.37067 4.06819 3.74114 3.57241 4.23691C2.93499 4.87434 2.49096 5.62891 2.24035 6.5006C1.99519 7.3723 1.92981 8.2903 2.04422 9.25462C2.15863 10.2189 2.43921 11.1642 2.88595 12.0904C3.33815 13.0165 3.94016 13.8555 4.692 14.6074C5.15509 15.0759 5.63725 15.4709 6.13847 15.7923C6.64515 16.1138 7.1382 16.3753 7.61763 16.5769C8.09707 16.7839 8.54109 16.9446 8.94969 17.059C9.36375 17.1789 9.71243 17.2715 9.99573 17.3369C10.2954 17.4132 10.5187 17.533 10.6658 17.6965C10.8184 17.8654 10.8919 18.0833 10.8865 18.3502C10.8756 18.6608 10.7557 18.8896 10.5269 19.0367C10.2981 19.1892 10.0012 19.2383 9.63616 19.1838C9.33106 19.1402 8.94152 19.0558 8.46754 18.9305C7.999 18.8052 7.47598 18.6199 6.89848 18.3748C6.32643 18.135 5.73531 17.8163 5.12512 17.4186C4.51494 17.0209 3.92109 16.5333 3.34359 15.9558ZM6.63697 13.4061L8.68819 12.6215C9.11859 13.0465 9.60619 13.4006 10.151 13.6839C10.7013 13.9672 11.2706 14.1552 11.859 14.2478C12.4474 14.3404 13.0194 14.3132 13.5751 14.1661C14.1308 14.0135 14.6348 13.7112 15.087 13.259C15.5719 12.7795 15.8715 12.202 15.9859 11.5265C16.1058 10.8455 16.0595 10.1236 15.847 9.36086C15.6345 8.59267 15.2777 7.84084 14.7764 7.10534L16.1575 5.73242C16.7296 6.52784 17.16 7.34233 17.4487 8.17589C17.7429 9.00401 17.9009 9.81305 17.9227 10.603C17.9445 11.393 17.8301 12.1312 17.5795 12.8177C17.3343 13.4987 16.9557 14.098 16.4436 14.6156C15.9423 15.1168 15.3621 15.4873 14.7029 15.727C14.0491 15.9612 13.3572 16.0756 12.6272 16.0702C11.9026 16.0702 11.178 15.964 10.4534 15.7515C9.72877 15.539 9.03686 15.2339 8.37764 14.8362C7.72387 14.4385 7.14365 13.9618 6.63697 13.4061ZM8.35313 11.7716L6.38364 12.5153C6.24199 12.5698 6.10851 12.5398 5.9832 12.4254C5.86334 12.311 5.83338 12.1748 5.89331 12.0168L6.66149 10.0718L14.0982 2.64334L15.7898 4.33498L8.35313 11.7716ZM16.4191 3.7139L14.7274 2.02226L15.5119 1.23773C15.7244 1.0307 15.9696 0.91357 16.2474 0.886329C16.5307 0.859088 16.7623 0.938086 16.9421 1.12332L17.2363 1.40935C17.4487 1.62182 17.5441 1.87244 17.5223 2.16119C17.5059 2.44449 17.3915 2.69782 17.1791 2.9212L16.4191 3.7139Z"
              fill="white"
            />
          </svg>
        </div>
      </div>
      """
    end
  end

  _docp = """
    Currently the intro_content for a revision does not support h1 tags. So,
    if there is no <h1> tag in the content then we need to add an additional margin
    to match the given figma design.
  """

  defp maybe_additional_margin_top(content) do
    if !String.contains?(Jason.encode!(content), "\"type\":\"h1\""), do: "mt-[52px]"
  end

  defp to_formatted_datetime(nil, _ctx, _format), do: "not yet scheduled"

  defp to_formatted_datetime(datetime, ctx, format) do
    if is_binary(datetime) do
      datetime
      |> to_datetime
      |> FormatDateTime.parse_datetime(ctx, format)
    else
      FormatDateTime.parse_datetime(datetime, ctx, format)
    end
  end

  defp to_datetime(nil), do: "not yet scheduled"

  defp to_datetime(string_datetime) do
    {:ok, datetime, _} = DateTime.from_iso8601(string_datetime)

    datetime
  end

  defp get_module(hierarchy, unit_uuid, module_uuid) do
    unit =
      Enum.find(hierarchy["children"], fn unit ->
        unit["uuid"] == unit_uuid
      end)

    Enum.find(unit["children"], fn module ->
      module["uuid"] == module_uuid
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

    raw_avg_score_per_page_id =
      Metrics.raw_avg_score_across_for_pages(section, page_ids, [current_user_id])

    progress_per_resource_id = Map.merge(progress_per_page_id, progress_per_container_id)

    {visited_pages_map, progress_per_resource_id, raw_avg_score_per_page_id}
  end

  defp mark_visited_pages(module, visited_pages) do
    update_in(
      module,
      ["children"],
      &Enum.map(&1, fn page ->
        Map.put(page, "visited", Map.get(visited_pages, page["revision"]["id"], false))
      end)
    )
  end

  defp parse_student_progress_for_resource(student_progress_per_resource_id, resource_id) do
    Map.get(student_progress_per_resource_id, resource_id, 0.0)
    |> Kernel.*(100)
    |> round()
    |> trunc()
  end

  defp parse_minutes(minutes) when minutes in ["", nil], do: "?"
  defp parse_minutes(minutes), do: minutes

  defp async_calculate_student_metrics_and_enable_slider_buttons(
         liveview_pid,
         section,
         %User{id: current_user_id}
       ) do
    Task.async(fn ->
      send(
        liveview_pid,
        {:student_metrics_and_enable_slider_buttons,
         get_student_metrics(section, current_user_id)}
      )
    end)
  end

  defp async_calculate_student_metrics_and_enable_slider_buttons(
         liveview_pid,
         _section,
         _current_user
       ) do
    Task.async(fn ->
      send(
        liveview_pid,
        {:student_metrics_and_enable_slider_buttons, nil}
      )
    end)
  end

  defp is_page(%{"resource_type_id" => resource_type_id}),
    do: resource_type_id == Oli.Resources.ResourceType.get_id_by_type("page")

  _docp = """
    When a user collapses a module card, we do not want to autoscroll in the Y
    direction to focus on the unit that contains that card.
  """

  defp maybe_scroll_y_to_unit(socket, _unit_uuid, false), do: socket

  defp maybe_scroll_y_to_unit(socket, unit_uuid, true) do
    push_event(socket, "scroll-to-target", %{id: "unit_#{unit_uuid}", offset: 80})
  end

  defp module_has_intro_video(module), do: module["revision"]["intro_video"] != nil

  _docp = """
  This function returns the end date for a resource considering the student exception (if any)
  """

  defp get_due_date_for_student(end_date, resource_id, section_id, student_id, context, format) do
    IO.inspect(end_date, label: "end_date")
    IO.inspect(resource_id, label: "resource_id")
    IO.inspect(section_id, label: "section_id")
    IO.inspect(student_id, label: "student_id")
    IO.inspect(context, label: "context")
    IO.inspect(format, label: "format")

    case Oli.Delivery.Settings.get_student_exception(resource_id, section_id, student_id) do
      nil ->
        end_date

      student_exception ->
        student_exception.end_date
    end
    |> to_formatted_datetime(context, format)
  end
end
