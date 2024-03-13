defmodule OliWeb.Users.VrUserAgentsView do
  alias Oli.Accounts
  use OliWeb, :live_view

  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Repo
  alias Phoenix.LiveView.JS

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb()
    |> breadcrumb()
  end

  def breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "VR User Agents",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__)
        })
      ]
  end

  # Search |__email__| :: x user_1: value x <add>
  #                    :: x user_2: value x <add>
  # add_all_selected
  #
  # user_id | user_email | value | delete |
  #    1    | user_email |   x   |   btn  |
  #    2    | user_email |   o   |   btn  |
  #
  # Reset cache

  def mount(_, _session, socket) do
    data_manager = %{sort: {:asc, "id"}, paginate: nil}
    vr_user_agents = Oli.Accounts.all_vr_user_agents(sort_by: data_manager.sort)

    form = to_form(%{"search_text" => "", "search_by" => "email"})

    socket =
      socket
      |> assign(breadcrumbs: set_breadcrumbs())
      |> assign(vr_user_agents: vr_user_agents)
      |> assign(search_input: "")
      |> assign(search_results: [])
      |> assign(form: form)
      |> assign(data_manager: data_manager)

    {:ok, socket}
  end

  # def handle_params(_params, _, socket) do
  # {:noreply, socket}
  # end

  def render(assigns) do
    ~H"""
    <div>
      <div phx-click-away={JS.hide(to: "#search_users_result")} class="input-group w-1/2 flex gap-2">
        <div>
          <form phx-change="search_user">
            <.input
              type="text"
              field={@form[:search_text]}
              placeholder="Find record by name"
              autofocus
              autocomplete="off"
              phx-focus={JS.show(to: "#search_users_result")}
            />
            <div class="form-check-label flex flex-row gap-2 cursor-pointer">
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
                  <%!-- <div class="text-left w-[100px] overflow-ellipsis overflow-hidden whitespace-nowrap inline-block">
                    <%= result.user_email %>
                  </div> --%>
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
      <%= if 5 > 0 do %>
        <div class="d-flex justify-content-between items-center px-5 py-2">
          <%= "Showing all results (#{5} total)" %>
        </div>
      <% else %>
        <p>None exist</p>
      <% end %>
      <table class="min-w-full border ">
        <thead>
          <tr>
            <th
              :for={
                {sort_field, column_title} <- [
                  id: "User ID",
                  name: "Name",
                  value: "Value",
                  nil: "Delete"
                ]
              }
              phx-click="sort_by"
              phx-value-sort-column={sort_field}
            >
              <%= column_title %>
              <i class="fas fa-sort-up"></i>
              <i class="fas fa-sort-down"></i>
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

  # def handle_event("add_entry", %{"user-id" => user_id} = params, socket) do
  # filter_fn = fn -> Access.filter(&(&1.user_id == String.to_integer(user_id))) end
  # params |> IO.inspect(label: "params")
  # get_in(socket.assigns.search_results, [filter_fn.()]) |> IO.inspect(label: "ASD")
  # {:noreply, socket}
  # end

  def handle_event("add_entry", %{"user-id" => user_id}, socket) do
    # socket.assigns.search_results |> IO.inspect(label: "---A1")
    filter_fn = fn -> Access.filter(&(&1.user_id == String.to_integer(user_id))) end
    [data] = get_in(socket.assigns.search_results, [filter_fn.()])
    data |> IO.inspect(label: "---data")
    # socket.assigns.form.source["search_by"]
    # socket.assigns.form.source["search_text"]
    # socket.assigns.form.source["search_by"] |> IO.inspect(label: "---ASD")
    %Oli.Accounts.Schemas.VrUserAgent{}
    |> Oli.Accounts.Schemas.VrUserAgent.changeset(data)
    |> Oli.Repo.insert()

    search_by = socket.assigns.form.source["search_by"]
    search_text = socket.assigns.form.source["search_text"]

    search_results = Accounts.search_user_for_vr(search_text, search_by)

    socket =
      assign(socket, vr_user_agents: Oli.Accounts.all_vr_user_agents())
      |> assign(search_results: search_results)

    {:noreply, socket}
  end

  def handle_event("search_user", %{"search_text" => ""} = params, socket) do
    params |> IO.inspect(label: "--params")
    form = to_form(params) |> IO.inspect(label: "---form")
    socket = assign(socket, form: form)
    socket = assign(socket, search_results: [])
    {:noreply, socket}
  end

  def handle_event("search_user", params, socket) do
    form = to_form(params)

    results_found =
      Accounts.search_user_for_vr(form.source["search_text"], form.source["search_by"])

    socket = assign(socket, form: form)
    socket = assign(socket, search_results: results_found)
    {:noreply, socket}
  end

  # def handle_event(
  #       "search_user",
  #       %{
  #         "vr_user_agents_embed" =>
  #           %{"search_by" => search_by, "search_text" => search_text} = params
  #       },
  #       socket
  #     ) do
  #   search_by |> IO.inspect(label: "--search_by")
  #   search_text |> IO.inspect(label: "--search_text")

  #   form =
  #     socket.assigns.form.source
  #     |> Ecto.Changeset.put_change(:search_by, search_by)
  #     |> Ecto.Changeset.put_change(:search_text, search_text)
  #     |> to_form()
  #     |> IO.inspect(label: "---ASDASD")

  #   socket = assign(socket, form: form)
  #   socket.assigns.form.data |> IO.inspect(label: "socket.assigns.form.source.data")

  #   to_form(params)
  #   |> IO.inspect(label: "--AAA")

  #   # form.data.search_by |> IO.inspect(label: "form.data.search_by")
  #   # form.data.search_by |> IO.inspect(label: "form.data.search_by")
  #   # search_text = Ecto.Changeset.get_field(socket.assigns.form.source, :search_text)
  #   # search_by = Ecto.Changeset.get_field(socket.assigns.form.source, :search_by)

  #   # socket.assigns.form |> IO.inspect(label: "---A1")

  #   # Ecto.Changeset.apply_changes(socket.assigns.form.source)
  #   # |> IO.inspect(label: "---A2")

  #   # search_text |> IO.inspect(label: "search_text")
  #   # search_by |> IO.inspect(label: "search_by")

  #   {:noreply, socket}
  # end

  # def handle_event("find_user", %{"search_user_data" => ""}, socket) do
  #   socket = assign(socket, search_results: [])
  #   {:noreply, socket}
  # end

  # def handle_event("find_user", %{"search_user_data" => user_data}, socket) do
  #   search_by = Ecto.Changeset.get_field(socket.assigns.form.source, :search_by)
  #   results_found = Accounts.search_user_for_vr(user_data, String.to_existing_atom(search_by))
  #   socket = assign(socket, search_results: results_found, search_user_data: user_data)
  #   {:noreply, socket}
  # end

  def handle_event("delete_vr_entry", %{"user-id" => user_id}, socket) do
    Repo.get_by(Oli.Accounts.Schemas.VrUserAgent, %{user_id: user_id})
    |> Repo.delete()

    search_by = socket.assigns.form.source["search_by"]
    search_text = socket.assigns.form.source["search_text"]

    search_results =
      case String.trim(search_text) do
        "" -> []
        _ -> Accounts.search_user_for_vr(search_text, search_by)
      end

    socket =
      assign(socket, vr_user_agents: Oli.Accounts.all_vr_user_agents())
      |> assign(search_results: search_results)

    {:noreply, socket}
  end

  def handle_event("change_vr_value", %{"user-id" => user_id}, socket) do
    vr_user_agent = Repo.get_by(Oli.Accounts.Schemas.VrUserAgent, %{user_id: user_id})

    vr_user_agent
    |> Oli.Accounts.Schemas.VrUserAgent.changeset(%{value: !vr_user_agent.value})
    |> Repo.update()

    socket = assign(socket, vr_user_agents: Oli.Accounts.all_vr_user_agents())
    {:noreply, socket}
  end

  def handle_event("sort_by", %{"sort-column" => column}, socket)
      when column in ["id", "name", "value"] do
    column |> IO.inspect(label: "column")
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
        vr_user_agents: Oli.Accounts.all_vr_user_agents(sort_by: socket.assigns.data_manager.sort)
      )

    {:noreply, socket}
  end

  def handle_event("sort_by", _, socket) do
    {:noreply, socket}
  end

  def i(:desc), do: :asc
  def i(:asc), do: :desc
end
