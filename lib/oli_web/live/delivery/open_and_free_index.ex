defmodule OliWeb.Delivery.OpenAndFreeIndex do
  use OliWeb, :live_view

  on_mount({Oli.LiveSessionPlugs.SetCurrentUser, :with_preloads})
  on_mount(Oli.LiveSessionPlugs.SetCtx)

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Enrollment, Section}
  alias OliWeb.Components.Delivery.Utils
  alias OliWeb.Common.SearchInput
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections.EnrollmentContextRole
  alias Oli.Repo

  import Ecto.Query, warn: false
  import OliWeb.Common.SourceImage

  @default_params %{text_search: ""}

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    sections =
      Sections.list_user_open_and_free_sections(socket.assigns.current_user)
      |> add_user_role(socket.assigns.current_user)
      |> add_instructors()

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
  def render(assigns) do
    ~H"""
    <main role="main" class="relative flex flex-col pb-[60px]">
      <Components.Header.header {assigns} />
      <div class="container mx-auto px-8">
        <h3 class="mt-4 mb-4">My Courses</h3>
        <div class="flex items-center w-full justify-between">
          <.link
            :if={is_independent_instructor?(@current_user)}
            href={~p"/sections/independent/create"}
            class="btn btn-md btn-outline-primary"
          >
            New Section
          </.link>
          <.form for={:search} phx-change="search_section" class="w-[330px]">
            <SearchInput.render
              id="section_search_input"
              name="search"
              placeholder="Search by course or instructor name"
              text={@params.text_search}
            />
          </.form>
        </div>

        <div class="grid grid-cols-12 mt-4">
          <div class="col-span-12">
            <%= if length(@sections) == 0 do %>
              <p>You are not enrolled in any courses.</p>
            <% else %>
              <div class="flex flex-wrap">
                <.link
                  :for={section <- @filtered_sections}
                  href={~p"/sections/#{section.slug}/overview"}
                  class="rounded-lg shadow-lg bg-white dark:bg-gray-600 max-w-xs mr-3 mb-3 border-2 border-transparent hover:border-blue-500 hover:no-underline"
                >
                  <img
                    class="rounded-t-lg object-cover h-64 w-96"
                    src={cover_image(section)}
                    alt="course image"
                  />
                  <span class="badge badge-info ml-2 mt-2 capitalize"><%= section.user_role %></span>
                  <div class="p-6">
                    <h5 class="text-gray-900 dark:text-white text-xl font-medium mb-2">
                      <%= section.title %>
                    </h5>
                    <p class="text-gray-700 dark:text-white text-base mb-4">
                      <%= section.description %>
                    </p>
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
    instructors_per_section = instructors_per_section(sections)

    sections
    |> Enum.map(fn section ->
      Map.merge(section, %{instructors: Map.get(instructors_per_section, section.id, [])})
    end)
  end

  defp instructors_per_section(sections) do
    section_ids = Enum.map(sections, & &1.id)
    instructor_context_role_id = ContextRoles.get_role(:context_instructor).id

    query =
      from(
        e in Enrollment,
        join: s in Section,
        on: e.section_id == s.id,
        join: ecr in EnrollmentContextRole,
        on: e.id == ecr.enrollment_id,
        where:
          s.id in ^section_ids and s.status == :active and e.status == :enrolled and
            ecr.context_role_id == ^instructor_context_role_id,
        preload: [:user],
        select: {s.id, e}
      )

    Repo.all(query)
    |> Enum.group_by(fn {section_id, _} -> section_id end, fn {_, enrollment} ->
      Utils.user_name(enrollment.user)
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
