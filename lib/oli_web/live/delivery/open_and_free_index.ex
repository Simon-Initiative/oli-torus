defmodule OliWeb.Delivery.OpenAndFreeIndex do
  use OliWeb, :live_view

  alias Oli.Delivery.Sections
  alias OliWeb.Components.Delivery.Utils
  alias OliWeb.Common.SearchInput
  alias Oli.Delivery.Metrics

  import Ecto.Query, warn: false
  import OliWeb.Common.SourceImage
  import OliWeb.Components.Delivery.Layouts

  on_mount {OliWeb.UserAuth, :ensure_authenticated}

  @default_params %{text_search: ""}

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    sections =
      Sections.list_user_open_and_free_sections(socket.assigns.current_user)
      |> add_user_role(socket.assigns.current_user)
      |> add_instructors()
      |> add_sections_progress(socket.assigns.current_user.id)

    {:ok,
     assign(socket,
       sections: sections,
       params: @default_params,
       filtered_sections: sections,
       show_role_badges: show_role_badges(sections)
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"text_search" => text_search}, _uri, socket) do
    filtered_sections =
      socket.assigns.sections
      |> maybe_filter_by_text(text_search)

    {:noreply,
     assign(socket,
       filtered_sections: filtered_sections,
       params: Map.put(socket.assigns.params, :text_search, text_search)
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl Phoenix.LiveView
  # TODO add bg image to welcome header when we can export it from Figma

  def render(assigns) do
    ~H"""
    <main role="main" class="relative flex flex-col pb-[60px]">
      <Components.Header.header {assigns} />
      <div id="content" class="transition-all duration-100">
        <div class="relative flex items-center h-[247px] w-full bg-gray-100 dark:bg-[#0B0C11]">
          <div
            class="absolute top-0 left-0 h-full w-full"
            style="background: linear-gradient(90deg, #D9D9D9 0%, rgba(217, 217, 217, 0.00) 100%);"
          />
          <h1 class="text-[64px] leading-[87px] tracking-[0.02px] pl-[100px] z-10">
            Hi, <span class="font-bold"><%= user_given_name(@ctx) %></span>
          </h1>
        </div>
        <div class="flex flex-col items-start py-[60px] px-[100px]">
          <div class="flex mb-9 w-full">
            <h3 class="w-full text-[26px] leading-[32px] tracking-[0.02px] font-semibold dark:text-white">
              Courses available
            </h3>
            <div class="ml-auto flex items-center w-full justify-end gap-3">
              <.link
                :if={is_independent_instructor?(@current_user)}
                href={~p"/sections/independent/create"}
                class="torus-button primary !py-[10px] !px-5 !rounded-[3px] !text-sm flex items-center justify-center"
              >
                New Section
              </.link>
              <.form for={%{}} phx-change="search_section" class="w-[330px]">
                <SearchInput.render
                  id="section_search_input"
                  name="text_search"
                  placeholder="Search by course or instructor name"
                  text={@params.text_search}
                />
              </.form>
            </div>
          </div>

          <div class="flex w-full mb-10">
            <%= if length(@sections) == 0 do %>
              <p>You are not enrolled in any courses.</p>
            <% else %>
              <div class="flex flex-col w-full gap-3">
                <.link
                  :for={{section, index} <- Enum.with_index(@filtered_sections)}
                  href={get_course_url(section)}
                  phx-click={JS.add_class("opacity-0", to: "#content")}
                  phx-mounted={
                    JS.transition(
                      {"ease-out duration-300", "opacity-0 -translate-x-1/2",
                       "opacity-100 translate-x-0"},
                      time: 300 + index * 60
                    )
                    |> JS.remove_class("opacity-100 translate-x-0")
                  }
                  class="opacity-0 relative flex items-center self-stretch h-[201px] w-full bg-cover py-12 px-24 text-white hover:text-white rounded-xl shadow-lg hover:no-underline transition-all hover:translate-x-3"
                  style={"background-image: url('#{cover_image(section)}');"}
                >
                  <div class="top-0 left-0 rounded-xl absolute w-full h-full mix-blend-difference bg-[linear-gradient(180deg,rgba(0,0,0,0.00)_0%,rgba(0,0,0,0.80)_100%),linear-gradient(90deg,rgba(0,0,0,0.80)_0%,rgba(0,0,0,0.40)_100%)]" />
                  <div class="top-0 left-0 rounded-xl absolute w-full h-full dark:bg-black/40" />
                  <div class="top-0 left-0 rounded-xl absolute w-full h-full backdrop-blur-[30px] bg-[rgba(0,0,0,0.01)]" />
                  <span
                    :if={section.progress == 100}
                    role={"complete_badge_for_section_#{section.id}"}
                    class="absolute w-32 top-0 right-0 rounded-tr-xl rounded-bl-xl bg-[#0CAF61] uppercase py-2 text-center text-[12px] leading-[16px] tracking-[1.2px] font-bold"
                  >
                    Complete
                  </span>
                  <span
                    :if={@show_role_badges}
                    role={"role_badge_for_section_#{section.id}"}
                    class="badge absolute w-32 top-0 left-0 rounded-br-xl rounded-tl-xl bg-primary uppercase py-2 text-white text-center text-[12px] leading-[16px] tracking-[1.2px] font-bold"
                  >
                    <%= section.user_role %>
                  </span>
                  <div class="z-10 flex w-full items-center">
                    <div class="flex flex-col items-start gap-6">
                      <h5 class="text-[36px] leading-[49px] font-semibold drop-shadow-md">
                        <%= section.title %>
                      </h5>
                      <div
                        :if={section.user_role == "student"}
                        class="flex drop-shadow-md"
                        role={"progress_for_section_#{section.id}"}
                      >
                        <h4 class="text-[16px] leading-[32px] tracking-[1.28px] uppercase mr-9">
                          Course Progress
                        </h4>
                        <.progress_bar percent={section.progress} show_percent={true} width="100px" />
                      </div>
                    </div>
                    <i class="fa-solid fa-arrow-right ml-auto text-2xl p-[7px] drop-shadow-md"></i>
                  </div>
                </.link>
                <p :if={length(@filtered_sections) == 0} class="mt-4">
                  No course found matching <strong>"<%= @params.text_search %>"</strong>
                </p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </main>
    <OliWeb.Components.Footer.delivery_footer license={
      Map.get(assigns, :has_license) && assigns[:license]
    } />
    """
  end

  @impl Phoenix.LiveView
  def handle_event("search_section", %{"text_search" => text_search}, socket) do
    {:noreply, push_patch(socket, to: ~p"/sections?#{%{text_search: text_search}}")}
  end

  defp add_user_role([], _user), do: []

  defp add_user_role(sections, user) do
    sections
    |> Enum.map(fn s ->
      Map.merge(s, %{user_role: Utils.user_role(s, user) |> Atom.to_string()})
    end)
  end

  defp add_instructors([]), do: []

  defp add_instructors(sections) do
    instructors_per_section = Sections.instructors_per_section(Enum.map(sections, & &1.id))

    sections
    |> Enum.map(fn section ->
      Map.merge(section, %{instructors: Map.get(instructors_per_section, section.id, [])})
    end)
  end

  defp add_sections_progress([], _user_id), do: []

  defp add_sections_progress(sections, user_id) do
    Enum.map(sections, fn section ->
      progress =
        Metrics.progress_for(section.id, user_id)
        |> Kernel.*(100)
        |> round()
        |> trunc()

      Map.merge(section, %{progress: progress})
    end)
  end

  defp maybe_filter_by_text(sections, nil), do: sections
  defp maybe_filter_by_text(sections, ""), do: sections

  defp maybe_filter_by_text(sections, text_search) do
    normalized_text_search = String.downcase(text_search)

    sections
    |> Enum.filter(fn section ->
      # searchs by course name or instructor name

      String.contains?(String.downcase(section.title), normalized_text_search) ||
        Enum.find(section.instructors, false, fn name ->
          String.contains?(
            String.downcase(name),
            normalized_text_search
          )
        end)
    end)
  end

  _docp =
    """
    Returns true if in any of the sections the user has "instructor" role.
    We do not want to show the role badge for students.
    """

  defp show_role_badges([]), do: false

  defp show_role_badges(sections) do
    Enum.reduce_while(sections, false, fn section, acc ->
      if section.user_role == "instructor" do
        {:halt, true}
      else
        {:cont, acc}
      end
    end)
  end

  defp get_course_url(%{user_role: "student", slug: slug}), do: ~p"/sections/#{slug}"
  defp get_course_url(%{slug: slug}), do: ~p"/sections/#{slug}/instructor_dashboard/manage"
end
