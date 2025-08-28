defmodule OliWeb.Admin.VrUserAgentsView do
  alias Oli.Accounts.VrUserAgent
  use OliWeb, :live_view

  alias Oli.VrUserAgents
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Common.Paging
  alias Phoenix.LiveView.JS

  @limit 10
  @initial_sort {:asc, "user_agent"}
  @initial_paginate %{limit: @limit, offset: 0}

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  defp columns_title_data, do: [{"id", "ID"}, {"user_agent", "User agent"}, {"nil", "Delete"}]

  def mount(_, _session, socket) do
    data_manager = %{sort: @initial_sort, paginate: @initial_paginate}

    vr_user_agents =
      VrUserAgents.vr_user_agents(sort: data_manager.sort, paginate: data_manager.paginate)

    form = VrUserAgent.new_changeset() |> to_form()

    socket =
      socket
      |> assign(breadcrumbs: breadcrumb())
      |> assign(vr_user_agents: vr_user_agents)
      |> assign(form: form)
      |> assign(data_manager: data_manager)
      |> assign(total_count: VrUserAgents.count())

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} phx-submit="add_user_agent" phx-change="change_content">
        <div class="flex flex-col gap-2 w-full">
          <.input
            id="entered_text"
            type="textarea"
            field={@form[:user_agent]}
            placeholder="Enter user agent to add"
            autofocus
            class="w-full focus:ring-2 focus:ring-blue-300 rounded-lg text-sm px-5 py-1.5 dark:bg-gray-800"
          />
        </div>
        <button type="submit" class="form-button btn btn-md btn-primary mt-3">
          Add
        </button>
      </.form>
      <Paging.render
        id="header_paging"
        total_count={@total_count}
        offset={@data_manager.paginate.offset}
        limit={@data_manager.paginate.limit}
        click={JS.push("paged_table_page_change")}
      />
      <table class="min-w-full border ">
        <thead>
          <tr>
            <th
              :for={{sort_field, col_title} <- columns_title_data()}
              phx-click="sort_by"
              phx-value-sort-column={sort_field}
            >
              {col_title}
              <% sort_data = @data_manager[:sort] %>
              <i :if={match?(^sort_data, {:asc, sort_field})} class="fa fa-sort-up"></i>
              <i :if={match?(^sort_data, {:desc, sort_field})} class="fa fa-sort-down"></i>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr :for={vr_user_agent <- @vr_user_agents}>
            <td class="mx-auto text-center">
              {vr_user_agent.id}
            </td>
            <td class="mx-auto text-center">
              {vr_user_agent.user_agent}
            </td>
            <td class="mx-auto text-center">
              <button
                type="button"
                phx-click="delete_vr_entry"
                phx-value-id={vr_user_agent.id}
                class="form-button btn btn-md btn-danger mt-3"
              >
                Delete
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  def handle_event("paged_table_page_change", %{"offset" => offset}, socket) do
    data_manager = %{
      socket.assigns.data_manager
      | paginate: %{limit: @limit, offset: String.to_integer(offset)}
    }

    socket =
      socket
      |> reload_vr_user_agents(data_manager)
      |> assign(data_manager: data_manager)

    {:noreply, socket}
  end

  def handle_event("change_content", %{"vr_user_agent" => %{"user_agent" => user_agent}}, socket) do
    form =
      %VrUserAgent{}
      |> VrUserAgent.changeset(%{user_agent: user_agent})
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("sort_by", %{"sort-column" => column}, socket)
      when column in ["id", "user_agent"] do
    {previous_direction, previous_sort_column} = socket.assigns.data_manager.sort

    data_manager =
      if column == previous_sort_column do
        %{socket.assigns.data_manager | sort: {i(previous_direction), column}}
      else
        %{socket.assigns.data_manager | sort: {:asc, column}}
      end

    socket =
      socket
      |> reload_vr_user_agents(data_manager)
      |> assign(data_manager: data_manager)

    {:noreply, socket}
  end

  def handle_event("sort_by", _, socket) do
    {:noreply, socket}
  end

  def handle_event(
        "add_user_agent",
        %{"vr_user_agent" => %{"user_agent" => user_agent}},
        socket
      ) do
    {socket.assigns.data_manager.sort, socket.assigns.data_manager.paginate}

    case VrUserAgents.insert(%{user_agent: String.trim(user_agent)}) do
      {:ok, _} ->
        form = VrUserAgent.new_changeset() |> to_form()

        Oli.VrLookupCache.reload()

        {:noreply, reload_vr_user_agents(socket) |> assign(form: form)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("delete_vr_entry", %{"id" => id}, socket) do
    case VrUserAgents.delete(id) do
      {:ok, _} ->
        form = VrUserAgent.new_changeset() |> to_form()

        Oli.VrLookupCache.reload()

        {:noreply, reload_vr_user_agents(socket) |> assign(form: form)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: changeset)}
    end
  end

  def reload_vr_user_agents(socket) do
    vr_user_agents =
      VrUserAgents.vr_user_agents(
        sort: socket.assigns.data_manager.sort,
        paginate: socket.assigns.data_manager.paginate
      )

    assign(socket, vr_user_agents: vr_user_agents, total_count: VrUserAgents.count())
  end

  def reload_vr_user_agents(socket, data_manager) do
    vr_user_agents =
      VrUserAgents.vr_user_agents(sort: data_manager.sort, paginate: data_manager.paginate)

    assign(socket, vr_user_agents: vr_user_agents, total_count: VrUserAgents.count())
  end

  defp i(:desc), do: :asc
  defp i(:asc), do: :desc

  defp breadcrumb(),
    do:
      OliWeb.Admin.AdminView.breadcrumb() ++
        [Breadcrumb.new(%{full_title: "VR User Agents", link: ~p"/admin"})]
end
