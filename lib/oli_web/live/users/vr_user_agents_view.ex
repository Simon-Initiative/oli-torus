defmodule OliWeb.Users.VrUserAgentsView do
  use OliWeb, :live_view

  alias Oli.Accounts.Schemas.VrUserAgent
  alias Oli.Repo
  alias Oli.VrUserAgents
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Common.Paging
  alias Phoenix.LiveView.JS

  @initial_sort {:asc, "id"}
  @initial_paginate %{limit: 10, offset: 0}
  @initial_data_manager %{sort: @initial_sort, paginate: @initial_paginate}
  @initial_form to_form(%{"search_text" => "", "search_by" => "email"})

  def mount(_, _session, socket) do
    vr_user_agents =
      VrUserAgents.vr_user_agents(sort_by: @initial_sort, paginate: @initial_paginate)

    socket =
      socket
      |> assign(breadcrumbs: breadcrumb())
      |> assign(vr_user_agents: vr_user_agents)
      |> assign(search_input: "")
      |> assign(search_results: [])
      |> assign(form: @initial_form)
      |> assign(data_manager: @initial_data_manager)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div phx-click-away={JS.hide(to: "#search_users_result")} class="input-group w-1/2 flex gap-2">
        <div>
          <form phx-change="search_user">
            <.input
              type="text"
              field={@form[:search_text]}
              placeholder={"Add record by #{@form.source["search_by"]}"}
              autofocus
              autocomplete="off"
              phx-focus={JS.show(to: "#search_users_result")}
            />
            <div class="form-check-label flex flex-row gap-2 mt-2 cursor-pointer">
              <div>
                <label>Name</label>
                <%= radio_button(@form, :search_by, "name", class: "form-check-input") %>
              </div>
              <div>
                <label>Email</label>
                <%= radio_button(@form, :search_by, "email", class: "form-check-input") %>
              </div>
              <div>
                <label>Id</label>
                <%= radio_button(@form, :search_by, "id", class: "form-check-input") %>
              </div>
            </div>
          </form>
        </div>
        <div class="relative">
          <div
            id="search_users_result"
            class="absolute overflow-hidden left-[0px] block max-w-sm bg-white border border-gray-200 rounded-lg shadow dark:border-gray-600 dark:bg-gray-850"
          >
            <div
              :if={@search_results != []}
              class="overflow-y-auto max-h-[150px] h-full px-2 pt-2 pb-1 w-full"
              style="scrollbar-color: rgb(30 30 30 / var(--tw-bg-opacity)) rgb(82 82 82 / var(--tw-border-opacity));"
            >
              <ul>
                <li
                  :for={result <- @search_results}
                  id={"search_results_#{result.user_id}"}
                  class="flex items-center justify-center w-full pb-2 gap-2"
                >
                  <div>
                    <span class="overflow" style="float: left; width: 100px">
                      <span><%= result.user_name %></span>
                    </span>
                  </div>
                  <div>
                    <span class="overflow" style="float: left; width: 100px">
                      <span><%= result.user_email %></span>
                    </span>
                  </div>
                  <div>
                    <input
                      type="checkbox"
                      phx-click="change_search_vr_value"
                      phx-value-user-id={result.user_id}
                      checked={result.value}
                      class="cursor-pointer"
                    />
                  </div>
                  <div>
                    <button
                      class="text-xs text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:ring-blue-300 font-medium rounded-lg text-sm px-3 py-1.5 me-2 dark:bg-blue-600 dark:hover:bg-blue-700 focus:outline-none dark:focus:ring-blue-800"
                      phx-click="add_entry"
                      phx-value-user-id={result.user_id}
                    >
                      Add
                    </button>
                  </div>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>
      <Paging.render
        id="header_paging"
        total_count={Repo.aggregate(VrUserAgent, :count)}
        offset={@data_manager.paginate.offset}
        limit={@data_manager.paginate.limit}
        click={JS.push("paged_table_page_change")}
      />
      <table class="min-w-full border ">
        <thead>
          <tr>
            <th
              :for={
                {sort_field, column_title} <- [
                  {"id", "User ID"},
                  {"name", "Name"},
                  {"value", "Value"},
                  {"nil", "Delete"}
                ]
              }
              phx-click="sort_by"
              phx-value-sort-column={sort_field}
            >
              <%= column_title %>
              <% sort_data = @data_manager[:sort] %>
              <i :if={match?(^sort_data, {:asc, sort_field})} class="fa fa-sort-up"></i>
              <i :if={match?(^sort_data, {:desc, sort_field})} class="fa fa-sort-down"></i>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr :for={vr_user_agent <- @vr_user_agents}>
            <td class="mx-auto text-center">
              <%= vr_user_agent.user_id %>
            </td>
            <td class="mx-auto text-center">
              <%= vr_user_agent.name %>
            </td>
            <td class="mx-auto text-center">
              <input
                type="checkbox"
                checked={vr_user_agent.value}
                phx-click="change_vr_value"
                phx-value-user-id={vr_user_agent.user_id}
                class="cursor-pointer"
              />
            </td>
            <td class="mx-auto text-center">
              <button
                type="button"
                phx-click="delete_vr_entry"
                phx-value-user-id={vr_user_agent.user_id}
                phx-value-user-name={vr_user_agent.name}
                class="focus:outline-none text-white bg-red-700 hover:bg-red-800 focus:ring-4 focus:ring-red-300 font-medium rounded-lg text-sm px-5 py-1.5 me-2 dark:bg-red-600 dark:hover:bg-red-700 dark:focus:ring-red-900"
              >
                Delete
              </button>
            </td>
          </tr>
        </tbody>
      </table>
      <button phx-click="reset_cache">Reset Cache</button>
    </div>
    <style>
      .overflow {
      overflow: hidden;
      -ms-text-overflow: ellipsis;
      text-overflow: ellipsis;
      white-space: nowrap;
      }

      .overflow:hover {
      overflow: visible;
      }

      .overflow:hover span {
      position: relative;
      background-color: rgb(30 30 30 / var(--tw-bg-opacity));
      padding: 0 10px 0 0;

      box-shadow: 0 0 4px 0 white;
      border-radius: 1px;
      }
    </style>
    """
  end

  def handle_event("reset_cache", _, socket) do
    {:noreply, socket}
  end

  def handle_event("change_search_vr_value", %{"user-id" => user_id} = _params, socket) do
    filter_fn = fn -> Access.filter(&(&1.user_id == String.to_integer(user_id))) end

    {_value, search_results} =
      get_and_update_in(
        socket.assigns.search_results,
        [filter_fn.(), :value],
        &{&1, !&1}
      )

    socket = assign(socket, search_results: search_results)

    {:noreply, socket}
  end

  def handle_event("add_entry", %{"user-id" => user_id}, socket) do
    filter_fn = fn -> Access.filter(&(&1.user_id == String.to_integer(user_id))) end
    [data] = get_in(socket.assigns.search_results, [filter_fn.()])

    %Oli.Accounts.Schemas.VrUserAgent{}
    |> Oli.Accounts.Schemas.VrUserAgent.changeset(data)
    |> Oli.Repo.insert()

    search_by = socket.assigns.form.source["search_by"]
    search_text = socket.assigns.form.source["search_text"]

    search_results = VrUserAgents.search_user_for_vr(search_text, search_by)

    vr_user_agents =
      VrUserAgents.vr_user_agents(
        sort_by: socket.assigns.data_manager.sort,
        paginate: socket.assigns.data_manager.paginate
      )

    socket = assign(socket, vr_user_agents: vr_user_agents)
    socket = assign(socket, search_results: search_results)

    {:noreply, socket}
  end

  def handle_event("search_user", %{"search_text" => ""} = params, socket) do
    form = to_form(params)
    socket = assign(socket, form: form)
    socket = assign(socket, search_results: [])
    {:noreply, socket}
  end

  def handle_event("search_user", params, socket) do
    form = to_form(params)

    results_found =
      VrUserAgents.search_user_for_vr(form.source["search_text"], form.source["search_by"])

    socket = assign(socket, form: form)
    socket = assign(socket, search_results: results_found)
    {:noreply, socket}
  end

  def handle_event("delete_vr_entry", %{"user-id" => user_id}, socket) do
    Repo.get_by(Oli.Accounts.Schemas.VrUserAgent, %{user_id: user_id})
    |> Repo.delete()

    search_by = socket.assigns.form.source["search_by"]
    search_text = socket.assigns.form.source["search_text"]

    search_results =
      case String.trim(search_text) do
        "" -> []
        _ -> VrUserAgents.search_user_for_vr(search_text, search_by)
      end

    vr_user_agents =
      VrUserAgents.vr_user_agents(
        sort_by: socket.assigns.data_manager.sort,
        paginate: socket.assigns.data_manager.paginate
      )

    socket = assign(socket, vr_user_agents: vr_user_agents)
    socket = assign(socket, search_results: search_results)

    {:noreply, socket}
  end

  def handle_event("change_vr_value", %{"user-id" => user_id}, socket) do
    vr_user_agent = Repo.get_by(Oli.Accounts.Schemas.VrUserAgent, %{user_id: user_id})

    vr_user_agent
    |> Oli.Accounts.Schemas.VrUserAgent.changeset(%{value: !vr_user_agent.value})
    |> Repo.update()

    vr_user_agents =
      VrUserAgents.vr_user_agents(
        sort_by: socket.assigns.data_manager.sort,
        paginate: socket.assigns.data_manager.paginate
      )

    socket = assign(socket, vr_user_agents: vr_user_agents)
    {:noreply, socket}
  end

  def handle_event("sort_by", %{"sort-column" => column}, socket)
      when column in ["id", "name", "value"] do
    {previous_direction, previous_sort_column} = socket.assigns.data_manager.sort

    data_manager =
      if column == previous_sort_column do
        %{socket.assigns.data_manager | sort: {i(previous_direction), column}}
      else
        %{socket.assigns.data_manager | sort: {:asc, column}}
      end

    socket = assign(socket, data_manager: data_manager)

    socket =
      assign(socket,
        vr_user_agents:
          VrUserAgents.vr_user_agents(
            sort_by: socket.assigns.data_manager.sort,
            paginate: data_manager.paginate
          )
      )

    {:noreply, socket}
  end

  def handle_event("sort_by", _, socket) do
    {:noreply, socket}
  end

  def handle_event("paged_table_page_change", %{"limit" => limit, "offset" => offset}, socket) do
    data_manager = %{
      socket.assigns.data_manager
      | paginate: %{limit: String.to_integer(limit), offset: String.to_integer(offset)}
    }

    socket = assign(socket, data_manager: data_manager)

    socket =
      assign(socket,
        vr_user_agents:
          VrUserAgents.vr_user_agents(
            sort_by: socket.assigns.data_manager.sort,
            paginate: data_manager.paginate
          )
      )

    {:noreply, socket}
  end

  def i(:desc), do: :asc
  def i(:asc), do: :desc

  def breadcrumb(),
    do:
      OliWeb.Admin.AdminView.breadcrumb() ++
        [Breadcrumb.new(%{full_title: "VR User Agents", link: ~p"/admin"})]
end
