defmodule OliWeb.Delivery.Student.ContentLive do
  use OliWeb, :live_view

  alias Oli.Accounts.{User}
  alias OliWeb.Common.FormatDateTime
  alias Oli.Delivery.{Metrics, Sections}
  alias Phoenix.LiveView.JS

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
       active_tab: :content,
       selected_module_per_unit_uuid: %{},
       student_visited_pages: %{},
       student_progress_per_resource_id: %{}
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
         {student_visited_pages, student_progress_per_resource_id}},
        socket
      ) do
    {:noreply,
     assign(socket,
       student_visited_pages: student_visited_pages,
       student_progress_per_resource_id: student_progress_per_resource_id,
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
    <div id="student_content" class="lg:container lg:mx-auto p-[25px]" phx-hook="Scroller">
      <.unit
        :for={child <- Sections.get_full_hierarchy(@section)["children"]}
        unit={child}
        ctx={@ctx}
        student_progress_per_resource_id={@student_progress_per_resource_id}
        selected_module_per_unit_uuid={@selected_module_per_unit_uuid}
      />
    </div>
    """
  end

  attr :unit, :map
  attr :ctx, :map, doc: "the context is needed to format the date considering the user's timezone"
  attr :student_progress_per_resource_id, :map
  attr :selected_module_per_unit_uuid, :map

  def unit(assigns) do
    ~H"""
    <div
      id={"unit_#{@unit["uuid"]}"}
      class="p-[25px] pl-[50px]"
      role={"unit_#{@unit["numbering"]["index"]}"}
    >
      <div class="mb-6 flex flex-col items-start gap-[6px]">
        <h3 class="text-[26px] leading-[32px] tracking-[0.02px] font-normal ml-2 dark:text-[#DDD]">
          <%= "#{@unit["numbering"]["index"]}. #{@unit["revision"]["title"]}" %>
        </h3>
        <div class="flex items-center w-full">
          <div class="flex items-center gap-3" role="schedule_details">
            <div class="text-[14px] leading-[32px] tracking-[0.02px] font-semibold">
              <span class="text-gray-400 opacity-80 dark:text-[#696974] dark:opacity-100 mr-1">
                Complete By:
              </span>
              <%= to_formatted_datetime(
                @unit["section_resource"]["end_date"],
                @ctx
              ) %>
            </div>
          </div>
          <div class="ml-auto w-36">
            <.progress_bar
              percent={
                parse_student_progress_for_resource(
                  @student_progress_per_resource_id,
                  @unit["revision"]["resource_id"]
                )
              }
              width="100px"
              role={"unit_#{@unit["numbering"]["index"]}_progress"}
            />
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
          class="flex gap-4 overflow-x-scroll overflow-y-hidden h-[178px] pt-[3px] px-[3px] -mt-[2px] -ml-[2px] scrollbar-hide"
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
      class="flex-col py-6 px-[50px] gap-x-4 lg:gap-x-12"
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
      <div class="flex">
        <div class="w-1/2 flex flex-col px-6">
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
            class="rounded-[4px] p-[10px] flex justify-center items-center mr-auto mt-[42px] text-[14px] leading-[19px] tracking-[0.024px] font-normal text-white bg-blue-500 hover:bg-blue-600 dark:text-white dark:bg-[rgba(255,255,255,0.10);] dark:hover:bg-gray-800"
          >
            Let's discuss?
          </button>
        </div>
        <div class="mt-[62px] w-1/2">
          <.index module={Map.get(@selected_module_per_unit_uuid, @unit["uuid"])} />
        </div>
      </div>
      <div class="flex items-center justify-center py-[6px] px-[10px] mt-6" role="collapse_bar">
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

  def index(assigns) do
    ~H"""
    <div
      :for={{page, page_index} <- Enum.with_index(@module["children"], 1)}
      class="flex gap-[14px] w-full"
      role={"page_#{page_index}_details"}
    >
      <div class="flex justify-center items-center gap-[10px] h-6 w-6 shrink-0">
        <svg
          :if={page["visited"]}
          xmlns="http://www.w3.org/2000/svg"
          height="1.25em"
          viewBox="0 0 448 512"
          role="visited_check_icon"
        >
          <path
            fill="#1E9531"
            d="M438.6 105.4c12.5 12.5 12.5 32.8 0 45.3l-256 256c-12.5 12.5-32.8 12.5-45.3 0l-128-128c-12.5-12.5-12.5-32.8 0-45.3s32.8-12.5 45.3 0L160 338.7 393.4 105.4c12.5-12.5 32.8-12.5 45.3 0z"
          />
        </svg>
      </div>
      <div
        phx-click="navigate_to_resource"
        phx-value-slug={page["revision"]["slug"]}
        class="flex shrink items-center gap-3 w-full border-b-2 border-gray-600 cursor-pointer hover:bg-gray-200/70 px-2 dark:border-[rgba(255,255,255,0.20);] dark:hover:bg-gray-800 dark:text-white"
      >
        <span class="text-[16px] leading-[22px] font-normal">
          <%= "#{@module["module_index_in_unit"]}.#{page_index} #{page["revision"]["title"]}" %>
        </span>
        <div class="flex items-center h-[42px] gap-[6px] ml-auto dark:text-white dark:opacity-50">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="20"
            height="20"
            viewBox="0 0 20 20"
            fill="none"
          >
            <path
              fill="currentColor"
              d="M18.125 10C18.125 12.1549 17.269 14.2215 15.7452 15.7452C14.2215 17.269 12.1549 18.125 10 18.125C7.84512 18.125 5.77849 17.269 4.25476 15.7452C2.73102 14.2215 1.875 12.1549 1.875 10C1.875 7.84512 2.73102 5.77849 4.25476 4.25476C5.77849 2.73102 7.84512 1.875 10 1.875C12.1549 1.875 14.2215 2.73102 15.7452 4.25476C17.269 5.77849 18.125 7.84512 18.125 10ZM0 10C0 12.6522 1.05357 15.1957 2.92893 17.0711C4.8043 18.9464 7.34784 20 10 20C12.6522 20 15.1957 18.9464 17.0711 17.0711C18.9464 15.1957 20 12.6522 20 10C20 7.34784 18.9464 4.8043 17.0711 2.92893C15.1957 1.05357 12.6522 0 10 0C7.34784 0 4.8043 1.05357 2.92893 2.92893C1.05357 4.8043 0 7.34784 0 10ZM9.0625 4.6875V10C9.0625 10.3125 9.21875 10.6055 9.48047 10.7812L13.2305 13.2812C13.6602 13.5703 14.2422 13.4531 14.5312 13.0195C14.8203 12.5859 14.7031 12.0078 14.2695 11.7188L10.9375 9.5V4.6875C10.9375 4.16797 10.5195 3.75 10 3.75C9.48047 3.75 9.0625 4.16797 9.0625 4.6875Z"
            />
          </svg>
          <span class="text-[12px] leading-[16px] font-bold uppercase tracking-[0.96px] w-[15px] text-right">
            <%= parse_minutes(page["revision"]["duration_minutes"]) %>
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
      <div class="rounded-xl absolute -top-[0.7px] -left-[0.7px] h-[163px] w-[289.5px] cursor-pointer bg-[linear-gradient(180deg,#D9D9D9_0%,rgba(217,217,217,0.00)_100%)] dark:bg-[linear-gradient(180deg,#223_0%,rgba(34,34,51,0.72)_52.6%,rgba(34,34,51,0.00)_100%)]" />
      <.page_icon :if={is_page(@module["revision"])} />
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
          <div
            :if={!@selected and !is_page(@module["revision"])}
            class="mt-auto flex h-[21px] justify-center items-center text-gray-600 dark:text-white z-10"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="10"
              height="5"
              viewBox="0 0 10 5"
              fill="currentColor"
            >
              <path opacity="0.5" d="M5 5L0 0H10L5 5Z" fill="currentColor" />
            </svg>
          </div>
        </div>
        <.progress_bar
          :if={!@selected and !is_page(@module["revision"])}
          percent={
            parse_student_progress_for_resource(
              @student_progress_per_resource_id,
              @module["revision"]["resource_id"]
            )
          }
          width="60%"
          show_percent={false}
          role={"card_#{@module_index}_progress"}
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

  def page_icon(assigns) do
    ~H"""
    <div class="h-[45px] w-[36px] absolute top-0 right-0" role="page_icon">
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

  _docp = """
    Currently the intro_content for a revision does not support h1 tags. So,
    if there is no <h1> tag in the content then we need to add an additional margin
    to match the given figma design.
  """

  defp maybe_additional_margin_top(content) do
    if !String.contains?(Jason.encode!(content), "\"type\":\"h1\""), do: "mt-[52px]"
  end

  defp to_formatted_datetime(nil, _ctx), do: "not yet scheduled"

  defp to_formatted_datetime(string_datetime, ctx) do
    string_datetime
    |> to_datetime
    |> FormatDateTime.parse_datetime(ctx, "{WDshort} {Mshort} {D}, {YYYY} ({h12}:{m}{am})")
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

    progress_per_resource_id = Map.merge(progress_per_page_id, progress_per_container_id)

    {visited_pages_map, progress_per_resource_id}
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
end
