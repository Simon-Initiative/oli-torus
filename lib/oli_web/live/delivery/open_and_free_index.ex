defmodule OliWeb.Delivery.OpenAndFreeIndex do
  use OliWeb, :live_view

  on_mount({Oli.LiveSessionPlugs.SetCurrentUser, :with_preloads})
  on_mount(Oli.LiveSessionPlugs.SetCtx)

  alias Oli.Delivery.Sections

  import OliWeb.Common.SourceImage

  def mount(_params, _session, socket) do
    sections = Sections.list_user_open_and_free_sections(socket.assigns.current_user)

    {:ok, assign(socket, sections: sections)}
  end

  def render(assigns) do
    ~H"""
    <main role="main" class="relative flex flex-col pb-[60px]">
      <Components.Header.header {assigns} />
      <div class="container mx-auto px-8">
        <h3 class="mt-4 mb-4">My Courses</h3>
        <.link
          :if={is_independent_instructor?(@current_user)}
          href={~p"/sections/independent/create"}
          class="btn btn-md btn-outline-primary"
        >
          New Section
        </.link>

        <div class="grid grid-cols-12 mt-4">
          <div class="col-span-12">
            <%= if length(@sections) == 0 do %>
              <p>You are not enrolled in any courses.</p>
            <% else %>
              <div class="flex flex-wrap">
                <.link
                  :for={section <- @sections}
                  href={~p"/sections/#{section.slug}/overview"}
                  class="rounded-lg shadow-lg bg-white dark:bg-gray-600 max-w-xs mr-3 mb-3 border-2 border-transparent hover:border-blue-500 hover:no-underline"
                >
                  <img
                    class="rounded-t-lg object-cover h-64 w-96"
                    src={cover_image(section)}
                    alt="course image"
                  />
                  <div class="p-6">
                    <h5 class="text-gray-900 dark:text-white text-xl font-medium mb-2">
                      <%= section.title %>
                    </h5>
                    <p class="text-gray-700 dark:text-white text-base mb-4">
                      <%= section.description %>
                    </p>
                  </div>
                </.link>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </main>
    <%= render(OliWeb.LayoutView, "_delivery_footer.html", assigns) %>
    """
  end
end
