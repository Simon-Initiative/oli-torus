defmodule OliWeb.Sections.LtiExternalToolsView do
  use OliWeb, :live_view

  alias Oli.Activities
  alias Oli.Delivery.Sections
  alias OliWeb.Icons
  alias OliWeb.Sections.Mount
  alias OliWeb.Common.{Breadcrumb, Utils}
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
              expanded: false,
              deployment_status:
                lti_activity_registration.lti_external_tool_activity_deployment.status,
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
    search_term = Map.get(params, "search_term", "")
    expanded_tools = Map.get(params, "expanded_tools", "") |> String.split(",", trim: true)

    # We filter again here to render the results
    filtered_tools = filter_tools(socket.assigns.tools, search_term, expanded_tools)

    {
      :noreply,
      socket
      |> assign(params: update_params(params, expanded_tools, socket.assigns.tools))
      |> assign(filtered_tools: filtered_tools)
    }
  end

  def handle_event("search", %{"search_term" => search_term}, socket) do
    %{params: params, tools: tools} = socket.assigns

    params =
      if search_term not in ["", nil] do
        # We need to filter here to determine which tools should be expanded
        filtered_tools = filter_tools(tools, search_term)

        expanded_ids =
          filtered_tools
          |> Enum.filter(& &1[:expanded])
          |> Enum.map(&Integer.to_string(&1.id))

        params = Map.put(params, "search_term", search_term)

        if expanded_ids != [],
          do: Map.put(params, "expanded_tools", Enum.join(expanded_ids, ",")),
          else: Map.delete(params, "expanded_tools")
      else
        params
        |> Map.delete("search_term")
        |> Map.delete("expanded_tools")
      end

    {:noreply,
     push_patch(socket,
       to: ~p"/sections/#{socket.assigns.section.slug}/lti_external_tools?#{params}"
     )}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         ~p"/sections/#{socket.assigns.section.slug}/lti_external_tools?#{Map.drop(socket.assigns.params, ["search_term", "expanded_tools"])}"
     )}
  end

  def handle_event("expand_all", _, socket) do
    %{tools: tools, params: params, section: section} = socket.assigns

    expanded_tools =
      tools
      |> Enum.map(& &1.id)
      |> Enum.join(",")

    params =
      params
      |> Map.put("expanded_tools", expanded_tools)
      |> Map.put("toggle_expand_button", "collapse_all")

    {:noreply, push_patch(socket, to: ~p"/sections/#{section.slug}/lti_external_tools?#{params}")}
  end

  def handle_event("collapse_all", _, socket) do
    %{params: params, section: section} = socket.assigns

    params =
      params
      |> Map.put("toggle_expand_button", "expand_all")
      |> Map.drop(["expanded_tools"])

    {:noreply, push_patch(socket, to: ~p"/sections/#{section.slug}/lti_external_tools?#{params}")}
  end

  def handle_event("toggle_tool", %{"id" => tool_id}, socket) do
    %{params: params, section: section, tools: tools} = socket.assigns

    current_expanded_ids =
      Map.get(params, "expanded_tools", "") |> String.split(",", trim: true)

    updated_expanded_ids =
      if tool_id in current_expanded_ids do
        List.delete(current_expanded_ids, tool_id)
      else
        [tool_id | current_expanded_ids]
      end

    params = update_params(params, updated_expanded_ids, tools)

    {:noreply, push_patch(socket, to: ~p"/sections/#{section.slug}/lti_external_tools?#{params}")}
  end

  def render(assigns) do
    ~H"""
    <div id="lti-external-tools" class="container flex flex-col">
      <div class="flex-1 flex flex-col space-y-6">
        <h2 class="text-lg font-bold leading-normal">
          LTI 1.3 External Tools
        </h2>
        <div class="text-base font-medium">
          External tools in this course inherit the page type (scored or practice). To pass learner roles, names, scores, and activity insights, you need to configure these tools for your course section.
        </div>
        <DeliveryUtils.search_box
          search_term={@params["search_term"]}
          on_search="search"
          on_change="search"
          on_clear_search={
            JS.push("clear_search") |> JS.dispatch("click", to: "#collapse_all_button")
          }
          class="w-96"
          placeholder="Search..."
        />

        <.toggle_expand_button active={@params["toggle_expand_button"]} />

        <.tool
          :for={tool <- @filtered_tools || @tools}
          tool={tool}
          section_slug={@section.slug}
          search_term={@params["search_term"]}
          expanded_tools={@params["expanded_tools"]}
          toggle_expand_button={@params["toggle_expand_button"]}
        />

        <div :if={@filtered_tools == []} class="text-base font-medium">
          No results found for <strong><%= @params["search_term"] %></strong>.
        </div>
      </div>
    </div>
    """
  end

  def toggle_expand_button(%{active: active} = assigns) when active in ["expand_all", nil] do
    ~H"""
    <div class="flex items-center justify-start w-32 px-2 text-sm font-bold text-[#0080FF] dark:text-[#0062F2]">
      <button id="expand_all_button" phx-click="expand_all" class="flex space-x-3">
        <Icons.expand />
        <span>Expand All</span>
      </button>
    </div>
    """
  end

  def toggle_expand_button(%{active: "collapse_all"} = assigns) do
    ~H"""
    <div class="flex items-center justify-start w-32 px-2 text-sm font-bold text-[#0080FF] dark:text-[#0062F2]">
      <button id="collapse_all_button" phx-click="collapse_all" class="flex space-x-3">
        <Icons.collapse />
        <span>Collapse All</span>
      </button>
    </div>
    """
  end

  attr :tool, :map, required: true
  attr :section_slug, :string, required: true
  attr :search_term, :string, default: ""
  attr :expanded_tools, :list, required: true
  attr :toggle_expand_button, :string, required: true

  def tool(assigns) do
    ~H"""
    <div id={"lti_external_tool_#{@tool.id}"} class="flex flex-col">
      <button
        class="flex flex-row items-center transition-transform duration-300 w-full h-12 border-b"
        type="button"
        phx-click="toggle_tool"
        phx-value-id={@tool.id}
        aria-expanded={"#{@tool.expanded}"}
      >
        <div class="text-lg font-semibold leading-normal flex items-center space-x-1">
          <%= if @tool.deployment_status == :deleted do %>
            <div class="relative group mr-2">
              <Icons.alert />
              <div class="absolute top-full left-0 mt-2 w-64 p-2 bg-white border rounded shadow-lg text-sm text-gray-500 font-normal hidden group-hover:block z-10">
                This tool is no longer registered in the system, and its functionality has been disabled.
              </div>
            </div>
          <% end %>
          <div class="search-result">
            {Phoenix.HTML.raw(Utils.highlight_search_term(@tool.title, @search_term))}
          </div>
        </div>
        <div
          id={"icon-#{@tool.id}"}
          class={"transition-transform duration-300 ml-auto #{if @tool.expanded, do: "rotate-180", else: ""}"}
        >
          <Icons.chevron_down />
        </div>
      </button>

      <ul
        id={"collapse-#{@tool.id}"}
        class={"#{if @tool.expanded, do: "block", else: "hidden"} transition-all duration-300"}
      >
        <li :for={child <- @tool.children} class="h-14 w-full border-b flex flex-row items-center">
          <.link
            href={
              ~p"/sections/#{@section_slug}/lesson/#{child.revision_slug}?#{[request_path: ~p"/sections/#{@section_slug}/lti_external_tools?#{%{expanded_tools: @expanded_tools, search_term: @search_term, toggle_expand_button: @toggle_expand_button}}"]}"
            }
            class="flex flex-row items-center space-x-4 text-black dark:text-white hover:no-underline hover:text-black/75 dark:hover:text-white/75"
          >
            <span class="w-6 text-sm font-semibold leading-none text-[#757682] dark:text-[#EEEBF5]/75">
              {child.numbering_index}
            </span>
            <span class="search-result text-base font-semibold leading-normal">
              {Phoenix.HTML.raw(Utils.highlight_search_term(child.title, @search_term))}
            </span>
          </.link>
        </li>
      </ul>
    </div>
    """
  end

  defp filter_tools(tools, search_term, expanded_tools \\ nil)

  defp filter_tools(tools, search_term, nil) when search_term in ["", nil], do: tools

  defp filter_tools(tools, search_term, expanded_tools) do
    search_term = String.downcase(search_term)

    Enum.reduce(tools, [], fn tool, acc ->
      tool_matches_search_term = String.contains?(String.downcase(tool.title), search_term)

      matching_children =
        Enum.filter(tool.children, fn child ->
          String.contains?(String.downcase(child.title), search_term)
        end)

      has_matching_children = matching_children != []

      cond do
        # If tool title matches, keep all children
        tool_matches_search_term ->
          expanded =
            case expanded_tools do
              nil ->
                has_matching_children

              ids ->
                Integer.to_string(tool.id) in ids
            end

          [Map.put(tool, :expanded, expanded) | acc]

        # If any children match but tool doesn't, keep only matching children
        has_matching_children ->
          expanded =
            case expanded_tools do
              nil -> true
              ids -> Integer.to_string(tool.id) in ids
            end

          [
            Map.put(tool, :children, matching_children)
            |> Map.put(:expanded, expanded)
            | acc
          ]

        # If neither tool nor children match, exclude from results
        true ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp update_params(params, [] = _expanded_tool_ids, _tools) do
    # no tool expanded => the toggle button should say "Expand all"
    params
    |> Map.delete("expanded_tools")
    |> Map.put("toggle_expand_button", "expand_all")
  end

  defp update_params(params, expanded_tool_ids, tools)
       when length(expanded_tool_ids) == length(tools) do
    # all tools expanded => the toggle button should say "Collapse all"
    params
    |> Map.put("expanded_tools", Enum.join(expanded_tool_ids, ","))
    |> Map.put("toggle_expand_button", "collapse_all")
  end

  defp update_params(params, expanded_tool_ids, _tools) do
    # some tools expanded => the toggle button should remain as is (expand_all or collapse_all)
    Map.put(params, "expanded_tools", Enum.join(expanded_tool_ids, ","))
  end
end
