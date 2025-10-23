defmodule OliWeb.Components.Delivery.DiscussionActivity do
  use OliWeb, :live_component

  alias OliWeb.Common.PagedTable
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Table.SortableTableModel
  alias Oli.Resources.Collaboration
  alias OliWeb.Discussion.TableModel, as: DiscussionTableModel
  alias OliWeb.CollaborationLive.InstructorTableModel, as: CollabSpaceTableModel
  alias OliWeb.Components.Modal

  alias Phoenix.LiveView.JS

  @default_params %{
    offset: 0,
    limit: 20,
    filter: :all
  }

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(
        title: assigns.section.title,
        description: assigns.section.description,
        limit: safe_to_integer(assigns.params["limit"] || @default_params.limit),
        filter: safe_to_atom(assigns.params["filter"] || @default_params.filter),
        offset: safe_to_integer(assigns.params["offset"] || @default_params.offset),
        section_slug: assigns.section.slug,
        ctx: assigns.ctx
      )
      |> do_filter()

    {:ok, socket}
  end

  attr(:ctx, :any, required: true)
  attr(:limit, :integer, default: 10)
  attr(:filter, :string, required: true)
  attr(:offset, :integer, required: true)
  attr(:count, :integer, required: true)
  attr(:collab_space_table_model, :map, required: true)
  attr(:discussion_table_model, :map, required: true)
  attr(:parent_component_id, :string, required: true)
  attr(:section_slug, :string, required: true)

  def render(assigns) do
    ~H"""
    <div class="p-10">
      <Modal.modal
        id="accept_post_modal"
        on_confirm={JS.push("accept_post", target: @myself) |> Modal.hide_modal("accept_post_modal")}
        on_cancel={JS.push("cancel_confirm_modal", target: @myself)}
      >
        <:title>Accept Post</:title>
        {"Are you sure you want to accept this post?"}
        <:confirm>OK</:confirm>
        <:cancel>Cancel</:cancel>
      </Modal.modal>

      <Modal.modal
        id="reject_post_modal"
        on_confirm={JS.push("reject_post", target: @myself) |> Modal.hide_modal("reject_post_modal")}
        on_cancel={JS.push("cancel_confirm_modal", target: @myself)}
      >
        <:title>Reject Post</:title>
        {"Are you sure you want to reject this post? This will also reject the replies if there is any."}
        <:confirm>OK</:confirm>
        <:cancel>Cancel</:cancel>
      </Modal.modal>
      <div class="bg-white dark:bg-gray-800 w-full">
        <h4 class="px-10 py-6 border-b border-b-gray-200 dark:border-b-gray-700 torus-h4">
          Discussion Activity
        </h4>

        <div class="flex items-end gap-2 px-10 py-6 border-b border-b-gray-200 dark:border-b-gray-700">
          <form phx-change="filter" phx-target={@myself}>
            <label class="cursor-pointer inline-flex flex-col gap-2">
              <small class="torus-small uppercase">Filter by</small>
              <select class="torus-select pr-32" name="filter">
                <option selected={@filter == :all} value="all">All</option>
                <option selected={@filter == :need_approval} value="need_approval">
                  Posts that Need Approval
                </option>
                <option selected={@filter == :need_response} value="need_response">
                  Posts Awaiting a Reply
                </option>
                <option selected={@filter == :by_discussion} value="by_discussion">
                  By Discussion
                </option>
              </select>
            </label>
          </form>
        </div>

        <div id="discussion_activity_table">
          <%= if @filter == :by_discussion do %>
            <PagedTable.render
              table_model={@collab_space_table_model}
              page_change={JS.push("paged_table_page_change", target: @myself)}
              total_count={@count}
              offset={@offset}
              limit={@limit}
              additional_table_class="border-0"
              limit_change={JS.push("paged_table_limit_change", target: @myself)}
              show_limit_change={true}
            />
          <% else %>
            <PagedTable.render
              table_model={@discussion_table_model}
              page_change={JS.push("paged_table_page_change", target: @myself)}
              total_count={@count}
              offset={@offset}
              limit={@limit}
              additional_table_class="border-0"
              limit_change={JS.push("paged_table_limit_change", target: @myself)}
              show_limit_change={true}
            />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    push_with(socket, %{filter: filter, offset: 0})
  end

  @impl true
  def handle_event("paged_table_page_change", %{"offset" => offset}, socket) do
    push_with(socket, %{offset: offset})
  end

  @impl true
  def handle_event(
        "paged_table_limit_change",
        params,
        socket
      ) do
    new_limit = OliWeb.Common.Params.get_int_param(params, "limit", 20)

    new_offset =
      OliWeb.Common.PagingParams.calculate_new_offset(
        socket.assigns.offset,
        new_limit,
        socket.assigns.count
      )

    push_with(socket, %{limit: new_limit, offset: new_offset})
  end

  @impl true
  def handle_event("display_accept_modal", %{"post_id" => post_id}, socket) do
    {:noreply,
     socket
     |> assign(post_id: post_id)}
  end

  @impl true
  def handle_event("accept_post", _, socket) do
    post = Collaboration.get_post_by(%{id: socket.assigns.post_id})

    case Collaboration.update_post(post, %{status: :approved}) do
      {:ok, _} ->
        {:noreply,
         do_filter(socket)
         |> assign(post_id: nil)}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply,
         socket
         |> assign(post_id: nil)}
    end
  end

  def handle_event("display_reject_modal", %{"post_id" => post_id}, socket) do
    {:noreply,
     socket
     |> assign(post_id: post_id)}
  end

  def handle_event("reject_post", _, socket) do
    post = Collaboration.get_post_by(%{id: socket.assigns.post_id})

    case Collaboration.delete_posts(post) do
      {number, nil} when number > 0 ->
        {:noreply,
         do_filter(socket)
         |> assign(post_id: nil)}

      _ ->
        {:noreply,
         socket
         |> assign(post_id: nil)}
    end
  end

  def handle_event("cancel_confirm_modal", _, socket) do
    {:noreply,
     socket
     |> assign(post_id: nil)}
  end

  defp do_filter(socket) do
    %{
      :section_slug => section_slug,
      :filter => filter,
      :limit => limit,
      :offset => offset,
      :ctx => ctx
    } = socket.assigns

    case filter do
      :by_discussion ->
        {:ok, collab_space_table_model} = CollabSpaceTableModel.new([], ctx, is_listing: false)

        {count, rows} =
          Collaboration.list_collaborative_spaces_in_section(section_slug,
            offset: offset,
            limit: limit
          )

        collab_space_table_model =
          SortableTableModel.update_from_params(
            collab_space_table_model,
            %{offset: offset}
          )

        collab_space_table_model = Map.put(collab_space_table_model, :rows, rows)

        assign(socket,
          collab_space_table_model: collab_space_table_model,
          count: count
        )

      _ ->
        {:ok, discussion_table_model} =
          DiscussionTableModel.new([], section_slug, socket.assigns.myself)

        {count, rows} =
          Collaboration.list_posts_in_section_for_instructor(section_slug, filter,
            offset: offset,
            limit: limit
          )

        discussion_table_model =
          SortableTableModel.update_from_params(
            discussion_table_model,
            %{offset: offset}
          )

        discussion_table_model =
          Map.put(discussion_table_model, :rows, rows)
          |> Map.put(:data, %{section_slug: section_slug, target: socket.assigns.myself})

        assign(socket,
          discussion_table_model: discussion_table_model,
          count: count
        )
    end
  end

  defp safe_to_atom(value) do
    case is_binary(value) do
      true -> String.to_existing_atom(value)
      _ -> value
    end
  end

  defp safe_to_integer(value) do
    case is_integer(value) do
      true -> value
      _ -> String.to_integer(value)
    end
  end

  defp push_with(socket, attrs) do
    {:noreply,
     push_patch(
       socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           :discussions,
           Map.merge(
             %{
               filter: socket.assigns.filter,
               offset: socket.assigns.offset
             },
             attrs
           )
         )
     )}
  end
end
