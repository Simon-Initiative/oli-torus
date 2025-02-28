defmodule OliWeb.Sections.Assistant.StudentConversationsLive do
  @moduledoc """
  LiveView for browsing a section's student assistant conversations
  """
  use OliWeb, :live_view

  alias Oli.Accounts
  alias Oli.Delivery.Sections
  alias Oli.Conversation
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Sections.Assistant.StudentConversationsTableModel
  alias OliWeb.Common.Params
  alias OliWeb.Common.{PagedTable, SearchInput}
  alias OliWeb.Components.Delivery.Dialogue
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount
  alias OliWeb.Common.{Breadcrumb}

  @default_params %{
    offset: 0,
    limit: 20,
    sort_order: :asc,
    sort_by: :student,
    text_search: nil
  }

  defp set_breadcrumbs(type, section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(type, section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Assistant Conversations",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(%{"section_slug" => section_slug}, session, socket) do
    # only allow admins to access this page for now
    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {:admin = type, _current_user, section} ->
        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(type, section),
           table_model: nil,
           conversation_messages: nil,
           selected_user: nil
         )}

      {_, _current_user, _section} ->
        Mount.handle_error(socket, {:error, :unauthorized})
    end
  end

  def handle_params(
        params,
        _,
        socket
      ) do
    params = decode_params(params)

    socket =
      socket
      |> assign(params: params)
      |> assign_new(:students, fn ->
        Conversation.get_students_with_conversation_count(socket.assigns.section.id)
        |> Enum.map(fn row ->
          Map.put(row, :student_resource_id, "#{row.user.id}-#{row.resource_id}")
        end)
      end)
      |> assign_new(:resource_titles, fn ->
        Sections.section_resource_titles(socket.assigns.section.slug)
      end)

    {total_count, rows} =
      apply_filters(socket.assigns.students, socket.assigns.resource_titles, params)

    {:ok, table_model} =
      StudentConversationsTableModel.new(rows, socket.assigns.resource_titles)

    table_model =
      Map.merge(table_model, %{
        rows: rows,
        sort_order: params.sort_order
      })
      |> SortableTableModel.update_sort_params(params.sort_by)

    case params do
      %{selected_user_id: selected_user_id, selected_resource_id: selected_resource_id}
      when not is_nil(selected_user_id) ->
        conversation_messages =
          Conversation.get_student_resource_conversation_messages(
            socket.assigns.section.id,
            selected_user_id,
            selected_resource_id
          )

        selected_user = Accounts.get_user!(selected_user_id)

        {:noreply,
         assign(socket,
           table_model: table_model,
           total_count: total_count,
           conversation_messages: conversation_messages,
           selected_user: selected_user,
           selected_resource_id: selected_resource_id
         )}

      _ ->
        {:noreply,
         assign(socket,
           table_model: table_model,
           total_count: total_count,
           conversation_messages: nil,
           selected_user: nil,
           selected_resource_id: nil
         )}
    end
  end

  defp apply_filters(rows, resource_titles, params) do
    rows =
      rows
      |> maybe_filter_by_text(params.text_search, resource_titles)
      |> sort_by(params.sort_by, params.sort_order, resource_titles)

    {length(rows), rows |> Enum.drop(params.offset) |> Enum.take(params.limit)}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto mb-10">
      <.loader :if={!@table_model} />

      <div :if={@table_model} class="flex flex-col-reverse md:flex-row">
        <div class={if @conversation_messages, do: "md:w-8/12", else: "flex-1"}>
          <div class="bg-white shadow-sm dark:bg-gray-800 dark:text-white">
            <div class="flex flex-col space-y-4 lg:space-y-0 lg:flex-row lg:justify-between px-9">
              <h4 class="torus-h4 whitespace-nowrap">Assistant Conversations</h4>

              <div class="flex flex-col">
                <form for="search" phx-change="search" class="pb-6 lg:ml-auto lg:pt-7">
                  <SearchInput.render id="search_input" name="text_search" text={@params.text_search} />
                </form>
                <div></div>
              </div>
            </div>

            <PagedTable.render
              table_model={@table_model}
              total_count={@total_count}
              offset={@params.offset}
              limit={@params.limit}
              page_change={JS.push("paged_table_page_change")}
              allow_selection={true}
              selection_change={JS.push("paged_table_selection_change")}
              sort={JS.push("paged_table_sort")}
              additional_table_class="instructor_dashboard_table"
              show_bottom_paging={false}
              limit_change={JS.push("paged_table_limit_change")}
              show_limit_change={true}
            />
          </div>
        </div>

        <div :if={@conversation_messages} class="md:w-4/12 flex flex-col">
          <div class="flex-1 bg-white shadow-sm dark:bg-gray-800 dark:text-white mb-4 md:mb-0 md:ml-4">
            <div class="flex flex-row justify-between">
              <div class="whitespace-nowrap px-6 py-3">
                <h4 class="font-bold">
                  <%= user_or_guest_name(@selected_user) %>
                </h4>
                <div :if={@selected_resource_id} class="text-sm text-gray-500 mt-1">
                  <%= @resource_titles[@selected_resource_id] %>
                </div>
              </div>
              <button class="px-6 py-3 text-2xl" phx-click="clear_selection">
                <i class="fa-solid fa-xmark"></i>
              </button>
            </div>

            <.messages conversation_messages={@conversation_messages} user={@selected_user} />
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :conversation_messages, :list
  attr :user, Oli.Accounts.User

  def messages(assigns) do
    ~H"""
    <div role="message container" id="message-container" class="max-h-screen overflow-y-auto pt-5">
      <div class="flex flex-col justify-end items-center px-6 py-6 gap-1.5 min-h-full">
        <%= for {message, index} <- Enum.with_index(@conversation_messages, 1), message.role in [:user, :assistant, :function] do %>
          <%= case message.role do %>
            <% :function -> %>
              <Dialogue.function index={index} content={message.content} name={message.name} />
            <% _ -> %>
              <Dialogue.chat_message
                index={index}
                content={message.content}
                user={if message.role == :assistant, do: :assistant, else: @user}
              />
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  def handle_event(
        "paged_table_selection_change",
        %{"id" => selection_ids},
        socket
      ) do
    {selected_user_id, selected_resource_id} = parse_selection_ids(selection_ids)

    {:noreply,
     push_patch(socket,
       to:
         route_to(
           socket,
           update_params(socket.assigns.params, %{
             selected_user_id: selected_user_id,
             selected_resource_id: selected_resource_id
           })
         )
     )}
  end

  def handle_event(
        "clear_selection",
        _params,
        socket
      ) do
    {:noreply,
     push_patch(socket,
       to:
         route_to(
           socket,
           update_params(socket.assigns.params, %{
             selected_user_id: nil,
             selected_resource_id: nil
           })
         )
     )}
  end

  def handle_event(
        "search",
        %{"text_search" => text_search},
        socket
      ) do
    {:noreply,
     push_patch(socket,
       to:
         route_to(
           socket,
           update_params(socket.assigns.params, %{
             text_search: text_search,
             offset: 0
           })
         )
     )}
  end

  def handle_event(
        "paged_table_page_change",
        %{"limit" => limit, "offset" => offset},
        socket
      ) do
    {:noreply,
     push_patch(socket,
       to:
         route_to(
           socket,
           update_params(socket.assigns.params, %{limit: limit, offset: offset})
         )
     )}
  end

  def handle_event(
        "paged_table_limit_change",
        params,
        %{assigns: %{params: current_params}} = socket
      ) do
    new_limit = Params.get_int_param(params, "limit", 20)

    new_offset =
      OliWeb.Common.PagingParams.calculate_new_offset(
        current_params.offset,
        new_limit,
        socket.assigns.total_count
      )

    {:noreply,
     push_patch(socket,
       to:
         route_to(
           socket,
           update_params(socket.assigns.params, %{limit: new_limit, offset: new_offset})
         )
     )}
  end

  def handle_event(
        "paged_table_sort",
        %{"sort_by" => sort_by} = _params,
        socket
      ) do
    {:noreply,
     push_patch(socket,
       to:
         route_to(
           socket,
           update_params(socket.assigns.params, %{
             sort_by: String.to_existing_atom(sort_by)
           })
         )
     )}
  end

  defp parse_selection_ids(selection_ids) do
    case String.split(selection_ids, "-") do
      [] ->
        {nil, nil}

      [user_id] ->
        {String.to_integer(user_id), nil}

      [user_id, resource_id] ->
        {String.to_integer(user_id), String.to_integer(resource_id)}
    end
  end

  defp decode_params(params) do
    %{
      offset: Params.get_int_param(params, "offset", @default_params.offset),
      limit: Params.get_int_param(params, "limit", @default_params.limit),
      sort_order:
        Params.get_atom_param(
          params,
          "sort_order",
          [:asc, :desc],
          @default_params.sort_order
        ),
      sort_by:
        Params.get_atom_param(
          params,
          "sort_by",
          [
            :student,
            :resource,
            :num_messages
          ],
          @default_params.sort_by
        ),
      text_search: Params.get_param(params, "text_search", @default_params.text_search),
      selected_user_id: Params.get_int_param(params, "selected_user_id", nil),
      selected_resource_id: Params.get_int_param(params, "selected_resource_id", nil)
    }
  end

  defp update_params(
         %{sort_by: current_sort_by, sort_order: current_sort_order} = params,
         %{
           sort_by: new_sort_by
         }
       )
       when current_sort_by == new_sort_by do
    toggled_sort_order = if current_sort_order == :asc, do: :desc, else: :asc
    update_params(params, %{sort_order: toggled_sort_order})
  end

  defp update_params(params, new_param) do
    Map.merge(params, new_param)
  end

  defp route_to(socket, params) do
    Routes.live_path(
      socket,
      __MODULE__,
      socket.assigns.section.slug,
      params
    )
  end

  defp maybe_filter_by_text(rows, nil, _), do: rows
  defp maybe_filter_by_text(rows, "", _), do: rows

  defp maybe_filter_by_text(rows, text_search, resource_titles) do
    Enum.filter(rows, fn row ->
      maybe_contains?(
        maybe_downcase(user_or_guest_name(row.user)),
        maybe_downcase(text_search)
      ) ||
        maybe_contains?(
          maybe_downcase(Map.get(resource_titles, row.resource_id)),
          maybe_downcase(text_search)
        )
    end)
  end

  defp sort_by(rows, sort_by, sort_order, resource_titles) do
    case sort_by do
      :student ->
        Enum.sort_by(
          rows,
          fn a -> maybe_downcase(a.user.name) end,
          sort_order
        )

      :resource ->
        Enum.sort_by(
          rows,
          fn a -> Map.get(resource_titles, a.resource_id) |> maybe_downcase end,
          sort_order
        )

      :num_messages ->
        Enum.sort_by(rows, fn a -> a.num_messages end, sort_order)
    end
  end

  defp maybe_downcase(nil), do: nil
  defp maybe_downcase(string), do: String.downcase(string)

  defp maybe_contains?(nil, _), do: false
  defp maybe_contains?(_, nil), do: false
  defp maybe_contains?(string, substring), do: String.contains?(string, substring)

  defp user_or_guest_name(user) do
    case user do
      %{name: nil} -> "Guest"
      %{name: name} -> name
    end
  end
end
