defmodule OliWeb.Delivery.StudentDashboard.CourseContentLive do
  use OliWeb, :live_view

  alias OliWeb.Components.Delivery.Buttons
  alias Oli.Delivery.Sections

  @impl Phoenix.LiveView
  def mount(_params, %{"section_slug" => section_slug} = _session, socket) do
    section =
      Sections.get_section_by_slug(section_slug)
      |> Oli.Repo.preload([:base_project, :root_section_resource])

    hierarchy = Sections.build_hierarchy(section)

    {:ok, assign(socket, hierarchy: hierarchy)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-800 shadow-sm">
      <div class="flex flex-col divide-y divide-gray-100 dark:divide-gray-700">
        <section class="flex flex-col p-9">
          <h4 class="text-base font-semibold mr-auto">Course Content</h4>
          <span class="text-xs">Find all your course content, material, assignments and class activities here.</span>
        </section>
        <section class="flex flex-row justify-between p-9">
          <button>left arrow</button>
          <div class="flex flex-col">
            <h4 class="text-base font-semibold mx-auto">Unit 1: Composition of Substances and Solutions</h4>
            <div class="flex items-center justify-center space-x-3">
              <span class="uppercase text-xs">Unit 1 overall progress</span>
              <div class="w-40 rounded-full bg-gray-200 h-2">
                <div class="rounded-full bg-primary h-2" style={"width: #{30}%"}></div>
              </div>
            </div>
          </div>
          <button>right arrow</button>
        </section>
        <%= for resource <- [1,2,3] do %>
          <section class="flex flex-row w-full p-9">
            <div class="flex flex-col mr-4">
              <h4 class="text-base font-semibold"><%= "1.0 Intro to Chemistry 101: test #{resource}" %></h4>
              <span class="text-xs">Estimated completion time: 20 mins</span>
            </div>
            <span class="w-80 text-center text-xs bg-gray-200 px-3 py-2 rounded-sm ml-auto mr-4">Due by 10-03-2023</span>
            <Buttons.button class="h-10">Open</Buttons.button>
          </section>
        <% end %>
      </div>

    </div>
    """
  end
end
