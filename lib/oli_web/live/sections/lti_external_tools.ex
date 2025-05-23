defmodule OliWeb.Sections.LtiExternalToolsView do
  use OliWeb, :live_view

  alias Oli.Activities
  alias Oli.Delivery.Sections
  alias OliWeb.Icons
  alias OliWeb.Sections.Mount
  alias OliWeb.Common.{Breadcrumb}
  alias OliWeb.Components.Delivery.Utils, as: DeliveryUtils

  defp set_breadcrumbs(type, section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(type, section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "LTI 1.3 External Tools",
          link: ~p"/sections/#{section.slug}/lti_external_tools"
        })
      ]
  end

  def mount(%{"section_slug" => section_slug}, _session, socket) do
    case Mount.for(section_slug, socket) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, _user, section} ->
        contained_pages_mapper = Sections.get_section_resources_with_lti_activities(section)

        tools =
          contained_pages_mapper
          |> Map.keys()
          |> Activities.list_lti_activity_registrations()
          |> Enum.sort_by(& &1.title)
          |> Enum.map(fn lti_activity_registration ->
            %{
              id: lti_activity_registration.id,
              title: lti_activity_registration.title,
              children:
                Map.get(contained_pages_mapper, lti_activity_registration.id, [])
                |> Enum.sort_by(& &1.numbering_index)
            }
          end)

        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(type, section),
           section: section,
           tools: tools
         )}
    end
  end

  def handle_params(params, _uri, socket) do
    params = %{"search_term" => params["search_term"]}

    {:noreply, assign(socket, params: params)}
  end

  def handle_event("search", %{"search_term" => search_term}, socket) do
    params =
      if search_term not in ["", nil] do
        Map.merge(socket.assigns.params, %{"search_term" => search_term})
      else
        Map.drop(socket.assigns.params, ["search_term"])
      end

    {:noreply,
     push_patch(socket,
       to: ~p"/sections/#{socket.assigns.section.slug}/lti_external_tools?#{params}"
     )}

    # TODO MER-4316: unhide the search box and apply the search and push an event to expand the tools that contain a page that matches the search term
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         ~p"/sections/#{socket.assigns.section.slug}/lti_external_tools?#{Map.drop(socket.assigns.params, ["search_term"])}"
     )}
  end

  def render(assigns) do
    ~H"""
    <div id="lti-external-tools" class="container flex flex-col">
      <div class="flex-1 flex flex-col space-y-6">
        <h2 class="text-lg font-bold leading-normal">
          LTI 1.3 External Tools
        </h2>
        <div class="text-base font-medium">
          External tools in this course inherit the page type (scored or practice). To pass learner roles, names, scores, and activity insights to the Torus, you need to configure these tools for your course section.
        </div>
        <DeliveryUtils.search_box
          search_term={@params["search_term"]}
          on_search="search"
          on_change="search"
          on_clear_search={
            JS.push("clear_search") |> JS.dispatch("click", to: "#collapse_all_button")
          }
          class="hidden w-64"
        />

        <DeliveryUtils.toggle_expand_button />
        <.tool :for={tool <- @tools} tool={tool} section_slug={@section.slug} />
      </div>
    </div>
    """
  end

  attr :tool, :map, required: true
  attr :section_slug, :string, required: true

  def tool(assigns) do
    ~H"""
    <div class="flex flex-col">
      <button
        class="flex flex-row items-center transition-transform duration-300 w-full h-12 border-b"
        type="button"
        phx-click={JS.toggle_class("rotate-180", to: "#icon-#{@tool.id}")}
        phx-value-id={@tool.id}
        data-bs-toggle="collapse"
        data-bs-target={"#collapse-#{@tool.id}"}
        data-child_matches_search_term={false}
        aria-expanded="false"
        aria-controls={"collapse-#{@tool.id}"}
      >
        <div class="text-lg font-semibold leading-normal">
          <%= @tool.title %>
        </div>
        <div id={"icon-#{@tool.id}"} class="transition-transform duration-300 ml-auto">
          <Icons.chevron_down />
        </div>
      </button>

      <ul id={"collapse-#{@tool.id}"} class="collapse">
        <li :for={child <- @tool.children} class="h-14 w-full border-b flex flex-row items-center">
          <.link
            href={~p"/sections/#{@section_slug}/lesson/#{child.revision_slug}"}
            class="flex flex-row items-center space-x-4 text-black dark:text-white hover:no-underline hover:text-black/75 dark:hover:text-white/75"
          >
            <span class="w-6 text-sm font-semibold leading-none text-[#757682] dark:text-[#EEEBF5]/75">
              <%= child.numbering_index %>
            </span>
            <span class="text-base font-semibold leading-normal"><%= child.title %></span>
          </.link>
        </li>
      </ul>
    </div>
    """
  end
end
