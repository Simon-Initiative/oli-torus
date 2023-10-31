defmodule OliWeb.Delivery.Student.ContentLive do
  use OliWeb, :live_view

  import OliWeb.Components.Delivery.Layouts

  alias OliWeb.Common.FormatDateTime
  alias Oli.Delivery.{Metrics, Sections}
  alias OliWeb.Components.Delivery.Utils

  def mount(_params, _session, socket) do
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
      if module_uuid == socket.assigns.selected_module["uuid"] do
        assign(socket, selected_unit_uuid: nil, selected_module: nil)
      else
        selected_module =
          get_module(socket.assigns.section.full_hierarchy, unit_uuid, module_uuid)
          |> mark_visited_pages(socket.assigns.student_visited_pages)

        assign(socket,
          selected_unit_uuid: unit_uuid,
          selected_module: selected_module,
          selected_module_index: selected_module_index
        )
      end
      |> push_event("scroll-to-target", %{id: "unit_#{unit_uuid}", offset: 80})

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
    <.header_with_sidebar_nav
      ctx={@ctx}
      section={@section}
      brand={@brand}
      preview_mode={@preview_mode}
      active_tab={:content}
    >
      <div id="student_content" class="container mx-auto p-[25px]" phx-hook="ScrollToTarget">
        <.unit
          :for={child <- @section.full_hierarchy["children"]}
          unit={child}
          section_start_date={@section.start_date}
          ctx={@ctx}
          unit_selected={child["uuid"] == @selected_unit_uuid}
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
    ~H"""
    <div id={"unit_#{@unit["uuid"]}"} class="p-[25px] pl-[50px]">
      <div class="mb-6 flex flex-col items-start gap-[6px]">
        <h3 class="text-[26px] leading-[32px] tracking-[0.02px] font-semibold ml-2">
          <%= "#{@unit["numbering"]["index"]}. #{@unit["revision"]["title"]}" %>
        </h3>
        <div class="flex items-center w-full">
          <div class="flex items-center gap-3 ">
            <div class="text-[14px] leading-[32px] tracking-[0.02px] font-semibold">
              <span class="text-gray-400 opacity-80">Week</span> <%= Utils.week_number(
                @section_start_date,
                to_datetime(@unit["section_resource"]["start_date"])
              ) %>
            </div>
            <div class="text-[14px] leading-[32px] tracking-[0.02px] font-semibold">
              <span class="text-gray-400 opacity-80">Complete by:</span> <%= parse_datetime(
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
            />
          </div>
        </div>
      </div>
      <div class="flex gap-4 overflow-x-scroll pt-[2px] pl-[2px] -mt-[2px] -ml-[2px]">
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
          selected={if @selected_module, do: module["uuid"] == @selected_module["uuid"], else: false}
        />
      </div>
    </div>
    <div :if={@unit_selected} class="flex py-[24px] px-[50px] gap-x-4 lg:gap-x-12">
      <div class="w-1/2 flex flex-col px-6">
        <div
          :if={@selected_module["revision"]["intro_content"]["children"]}
          class={[
            "intro-content",
            maybe_additional_margin_top(@selected_module["revision"]["intro_content"]["children"])
          ]}
        >
          <%= Phoenix.HTML.raw(
            Oli.Rendering.Content.render(
              %Oli.Rendering.Context{},
              @selected_module["revision"]["intro_content"]["children"],
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
    ~H"""
    <div
      :for={{page, page_index} <- Enum.with_index(@module["children"], 1)}
      class="flex gap-[14px] h-[42px] w-full"
    >
      <div class="flex justify-center items-center gap-[10px] h-6 w-6">
        <svg
          :if={page["visited"]}
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
        phx-value-slug={page["revision"]["slug"]}
        class="flex items-center gap-3 w-full border-b-2 border-gray-600 cursor-pointer hover:bg-gray-200/70 px-2"
      >
        <span class="text-[16px] leading-[22px] font-normal truncate">
          <%= "#{@module_index}.#{page_index} #{page["revision"]["title"]}" %>
        </span>
        <div class="flex items-center gap-[6px] ml-auto">
          <svg xmlns="http://www.w3.org/2000/svg" height="1.25em" viewBox="0 0 512 512">
            <path d="M464 256A208 208 0 1 1 48 256a208 208 0 1 1 416 0zM0 256a256 256 0 1 0 512 0A256 256 0 1 0 0 256zM232 120V256c0 8 4 15.5 10.7 20l96 64c11 7.4 25.9 4.4 33.3-6.7s4.4-25.9-6.7-33.3L280 243.2V120c0-13.3-10.7-24-24-24s-24 10.7-24 24z" />
          </svg>
          <span class="text-[12px] leading-[16px] font-bold uppercase tracking-[0.96px] w-[15px] text-right">
            <%= page["revision"]["duration_minutes"] %>
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
    <div class="hover:scale-[1.01]">
      <div class={[
        "flex flex-col items-center rounded-lg h-[162px] w-[288px] bg-gray-200 shrink-0 px-5 pt-[15px]",
        if(@bg_image_url in ["", nil],
          do: "bg-[url('/images/course_default.jpg')]",
          else: "bg-[url('#{@bg_image_url}')]"
        )
      ]}>
        <h5 class="text-[13px] leading-[18px] font-bold self-start"><%= @title %></h5>
        <div
          :if={@video_url}
          id={@card_uuid}
          phx-hook="VideoPlayer"
          class="w-[70px] h-[70px] relative my-auto -top-2 cursor-pointer"
        >
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
    <div class="relative hover:scale-[1.01]">
      <.page_icon :if={is_page(@module["revision"])} />
      <div class="h-[170px] w-[288px]">
        <div
          id={"module_#{@module["uuid"]}"}
          phx-click={
            if is_page(@module["revision"]), do: "navigate_to_resource", else: "select_module"
          }
          phx-value-unit_uuid={@unit_uuid}
          phx-value-module_uuid={@module["uuid"]}
          phx-value-slug={@module["revision"]["slug"]}
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
          <h5 class="text-[18px] leading-[25px] font-bold"><%= @module["revision"]["title"] %></h5>
          <div
            :if={!@selected and !is_page(@module["revision"])}
            class="mt-auto flex h-[21px] justify-center items-center"
          >
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
          :if={!@selected and !is_page(@module["revision"])}
          percent={
            parse_student_progress_for_resource(
              @student_progress_per_resource_id,
              @module["revision"]["resource_id"]
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

  attr(:percent, :integer, required: true)
  attr(:width, :string, default: "100%")
  attr(:show_percent, :boolean, default: true)

  def progress_bar(assigns) do
    ~H"""
    <div class="flex flex-row items-center mx-auto">
      <div class="flex justify-center w-full">
        <div class="rounded-full bg-gray-200 h-1" style={"width: #{@width}"}>
          <div class="rounded-full bg-[#1E9531] h-1" style={"width: #{@percent}%"}></div>
        </div>
      </div>
      <div :if={@show_percent} class="text-[16px] leading-[32px] tracking-[0.02px] font-bold">
        <%= @percent %>%
      </div>
    </div>
    """
  end

  def page_icon(assigns) do
    ~H"""
    <div class="h-[45px] w-[36px] absolute top-0 right-0">
      <img src={~p"/images/ng23/course_content/rectangle_421.png"} />
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
    if there is no <h1> tag in the content then we need to add an aditional margin
    to match the given figma design.
  """

  defp maybe_additional_margin_top(content) do
    if !String.contains?(Jason.encode!(content), "\"type\":\"h1\""), do: "mt-[52px]"
  end

  defp parse_datetime(nil, _ctx), do: "not yet scheduled"

  defp parse_datetime(string_datetime, ctx) do
    string_datetime
    |> to_datetime
    |> FormatDateTime.convert_datetime(ctx)
    |> Timex.format!("{WDshort} {Mshort} {D}, {YYYY}")
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

  defp async_calculate_student_metrics(liveview_pid, section, current_user_id) do
    Task.async(fn ->
      send(liveview_pid, {:student_metrics, get_student_metrics(section, current_user_id)})
    end)
  end

  defp is_page(%{"resource_type_id" => resource_type_id}),
    do: resource_type_id == Oli.Resources.ResourceType.get_id_by_type("page")
end
