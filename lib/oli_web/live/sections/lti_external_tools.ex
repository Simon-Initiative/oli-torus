defmodule OliWeb.Sections.LtiExternalToolsView do
  use OliWeb, :live_view

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

      # TODO: fetch the tools from the database

      {type, _user, section} ->
        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(type, section),
           section: section,
           tools: [
             %{
               id: 1,
               title: "Tool 1",
               children: [
                 %{id: 1, title: "Page 1", numbering_index: 1},
                 %{id: 2, title: "Page 2", numbering_index: 2}
               ]
             },
             %{
               id: 2,
               title: "Tool 2",
               children: [
                 %{id: 3, title: "Page 3", numbering_index: 3},
                 %{id: 4, title: "Page 4", numbering_index: 4}
               ]
             }
           ]
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

    # TODO: apply the search and push an event to expand the containers that contain a child that matches the search term
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
          class="w-64"
        />

        <DeliveryUtils.toggle_expand_button />
        <.tool :for={tool <- @tools} tool={tool} />
      </div>
    </div>
    """
  end

  attr :tool, :map, required: true

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
            href="#"
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
