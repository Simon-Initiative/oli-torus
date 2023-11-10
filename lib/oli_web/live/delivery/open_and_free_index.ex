defmodule OliWeb.Delivery.OpenAndFreeIndex do
  use OliWeb, :live_view

  on_mount({OliWeb.LiveSessionPlugs.SetCurrentUser, :with_preloads})
  on_mount(OliWeb.LiveSessionPlugs.SetCtx)

  alias Oli.Delivery.Sections
  alias OliWeb.Components.Delivery.Utils
  alias OliWeb.Common.SearchInput
  alias Oli.Delivery.Metrics

  import Ecto.Query, warn: false
  import OliWeb.Common.SourceImage
  import OliWeb.Components.Delivery.Layouts

  @default_params %{text_search: ""}

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    sections =
      Sections.list_user_open_and_free_sections(socket.assigns.current_user)
      |> add_user_role(socket.assigns.current_user)
      |> add_instructors()
      |> add_sections_progress(socket.assigns.current_user.id)

    {:ok,
     assign(socket, sections: sections, params: @default_params, filtered_sections: sections)}
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
        <div class="flex items-center h-[247px] bg-gray-300">
          <h1 class="text-[64px] leading-[87px] tracking-[0.02px] pl-[100px]">
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
                  name="search"
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
                  :for={section <- @filtered_sections}
                  href={~p"/sections/#{section.slug}/overview"}
                  phx-click={JS.add_class("opacity-0", to: "#content")}
                  class={"relative flex items-center self-stretch h-[201px] w-full bg-cover py-12 px-24 bg-[url('#{cover_image(section)}')] text-black hover:text-black dark:text-white dark:hover:text-white rounded-xl shadow-lg hover:no-underline hover:scale-[1.002] transition-all hover:translate-x-3"}
                >
                  <div class="top-0 left-0 rounded-xl absolute w-full h-full backdrop-blur" />
                  <span
                    :if={section.progress == 100}
                    role={"complete_badge_for_section_#{section.id}"}
                    class="absolute w-32 top-0 right-0 rounded-tr-xl rounded-bl-xl bg-[#0CAF61] uppercase py-2 text-black text-center text-[12px] leading-[16px] tracking-[1.2px] font-bold"
                  >
                    Complete
                  </span>
                  <span
                    role={"role_badge_for_section_#{section.id}"}
                    class="absolute w-32 top-0 left-0 rounded-br-xl rounded-tl-xl bg-primary uppercase py-2 text-white text-center text-[12px] leading-[16px] tracking-[1.2px] font-bold"
                  >
                    <%= section.user_role %>
                  </span>
                  <div class="z-10 flex w-full items-center">
                    <div class="flex flex-col items-start gap-6">
                      <h5 class="text-gray-900 text-[36px] leading-[49px] font-semibold dark:text-white">
                        <%= section.title %>
                      </h5>
                      <div
                        :if={section.user_role == "student"}
                        class="flex"
                        role={"progress_for_section_#{section.id}"}
                      >
                        <h4 class="text-[16px] leading-[32px] tracking-[1.28px] uppercase mr-9">
                          Course Progress
                        </h4>
                        <.progress_bar percent={section.progress} show_percent={true} width="100px" />
                      </div>
                    </div>
                    <i class="fa-solid fa-arrow-right ml-auto text-2xl p-[7px] dark:text-white"></i>
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
    <%= render(OliWeb.LayoutView, "_delivery_footer.html", assigns) %>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("search_section", %{"search" => text_search}, socket) do
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
end
