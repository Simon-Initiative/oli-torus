defmodule OliWeb.Components.Delivery.DiscussionActivityLive do
  use Surface.LiveView
  use OliWeb.Common.Modal

  alias OliWeb.Common.PagedTable
  alias OliWeb.Discussion.TableModel, as: DiscussionTableModel
  alias OliWeb.CollaborationLive.InstructorTableModel, as: CollabSpaceTableModel
  alias Oli.Resources.Collaboration
  alias OliWeb.Common.Confirm
  alias OliWeb.Common.Table.SortableTableModel

  data posts, :list, default: []
  data discussion_table_model, :struct
  data collab_space_table_model, :struct
  data filter, :string, default: "all"
  data limit, :number, default: 10
  data offset, :number, default: 0

  def mount(_params, %{"section_slug" => section_slug}, socket) do
    {count, posts} =
      Collaboration.list_posts_in_section_for_instructor(
        section_slug,
        :all,
        offset: socket.assigns.offset,
        limit: socket.assigns.limit
      )

    {:ok, discussion_table_model} = DiscussionTableModel.new(posts)
    {:ok, collab_space_table_model} = CollabSpaceTableModel.new([], %{}, is_listing: false)

    socket =
      assign(socket,
        discussion_table_model: discussion_table_model,
        collab_space_table_model: collab_space_table_model,
        count: count,
        section_slug: section_slug
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~F"""
    {render_modal(assigns)}

    <div class="p-10">
      <div class="bg-white w-full">
        <h4 class="px-10 py-6 border-b border-b-gray-200 torus-h4">Discussion Activity</h4>

        <div class="flex items-end gap-2 px-10 py-6 border-b border-b-gray-200">
          <form phx-change="filter">
            <label class="cursor-pointer inline-flex flex-col gap-2">
              <small class="torus-small uppercase">Filter by</small>
              <select value={@filter} class="torus-select pr-32" name="filter">
                <option value={"all"}>All</option>
                <option value={"need_approval"}>Posts that Need Approval</option>
                <option value={"need_response"}>Posts Awaiting a Reply</option>
                <option value={"by_discussion"}>By Discussion</option>
              </select>
            </label>
          </form>
        </div>

        <div id="discussion_activity_table">
          {#if @filter == :by_discussion}
            <PagedTable
              table_model={@collab_space_table_model}
              filter=""
              page_change="paged_table_page_change"
              total_count={@count}
              offset={@offset}
              limit={@limit}
              additional_table_class="border-0" />
          {#else}
            <PagedTable
              table_model={@discussion_table_model}
              filter=""
              page_change="paged_table_page_change"
              total_count={@count}
              offset={@offset}
              limit={@limit}
              additional_table_class="border-0" />
          {/if}
        </div>
      </div>
    </div>
    """
  end

  def handle_event("filter", %{"filter" => filter}, socket) do
    socket = do_filter(assign(socket, offset: 0), filter)
    {:noreply, socket}
  end

  def handle_event("display_accept_modal", %{"post_id" => post_id}, socket) do
    modal_assigns = %{
      title: "Accept Post",
      id: "accept_post_modal",
      ok: "accept_post",
      cancel: "cancel_confirm_modal"
    }

    display_confirm_modal(
      modal_assigns,
      "accept",
      assign(socket, post_id: post_id)
    )
  end

  def handle_event("accept_post", _, socket) do
    post = Collaboration.get_post_by(%{id: socket.assigns.post_id})

    case Collaboration.update_post(post, %{status: :approved}) do
      {:ok, _} ->
        socket = do_filter(socket, socket.assigns.filter)

        {:noreply,
         socket
         |> hide_modal(modal_assigns: nil)}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply,
         socket
         |> hide_modal(modal_assigns: nil)}
    end
  end

  def handle_event("display_reject_modal", %{"post_id" => post_id}, socket) do
    modal_assigns = %{
      title: "Reject Post",
      id: "reject_post_modal",
      ok: "reject_post",
      cancel: "cancel_confirm_modal"
    }

    display_confirm_modal(
      modal_assigns,
      "reject",
      assign(socket, post_id: post_id),
      "This will also reject the replies if there is any."
    )
  end

  def handle_event("reject_post", _, socket) do
    post = Collaboration.get_post_by(%{id: socket.assigns.post_id})

    case Collaboration.delete_posts(post) do
      {number, nil} when number > 0 ->
        socket = do_filter(socket, socket.assigns.filter)

        {:noreply,
         socket
         |> hide_modal(modal_assigns: nil)}

      _ ->
        {:noreply,
         socket
         |> hide_modal(modal_assigns: nil)}
    end
  end

  def handle_event("cancel_confirm_modal", _, socket) do
    {:noreply,
     socket
     |> hide_modal(modal_assigns: nil)}
  end

  def handle_event("paged_table_page_change", %{"offset" => offset}, socket) do
    socket = do_filter(assign(socket, offset: offset), socket.assigns.filter)
    {:noreply, socket}
  end

  defp display_confirm_modal(modal_assigns, action, socket, opt_text \\ "") do
    modal = fn assigns ->
      ~F"""
      <Confirm {...@modal_assigns}>
        Are you sure you want to {action} this post? {opt_text}</Confirm>
      """
    end

    {:noreply,
     show_modal(
       socket,
       modal,
       modal_assigns: modal_assigns
     )}
  end

  defp do_filter(socket, filter) do
    %{
      :section_slug => section_slug,
      :offset => offset,
      :limit => limit,
      :discussion_table_model => discussion_table_model,
      :collab_space_table_model => collab_space_table_model
    } = socket.assigns

    offset = safe_to_integer(offset)
    filter = safe_to_atom(filter)

    offset =
      case filter != safe_to_atom(socket.assigns.filter) do
        true -> 0
        _ -> offset
      end

    {count, rows} =
      case filter do
        :by_discussion ->
          Collaboration.list_collaborative_spaces_in_section(section_slug,
            offset: offset,
            limit: limit
          )

        _ ->
          Collaboration.list_posts_in_section_for_instructor(section_slug, filter,
            offset: offset,
            limit: limit
          )
      end

    if filter == :by_discussion do
      collab_space_table_model =
        SortableTableModel.update_from_params(
          collab_space_table_model,
          %{offset: offset}
        )

      collab_space_table_model = Map.put(collab_space_table_model, :rows, rows)

      assign(socket,
        collab_space_table_model: collab_space_table_model,
        filter: filter,
        offset: offset,
        count: count
      )
    else
      discussion_table_model =
        SortableTableModel.update_from_params(
          discussion_table_model,
          %{offset: offset}
        )

      discussion_table_model = Map.put(discussion_table_model, :rows, rows)

      assign(socket,
        discussion_table_model: discussion_table_model,
        filter: filter,
        offset: offset,
        count: count
      )
    end
  end

  defp safe_to_atom(value) do
    case is_binary(value) do
      true -> String.to_atom(value)
      _ -> value
    end
  end

  defp safe_to_integer(value) do
    case is_integer(value) do
      true -> value
      _ -> String.to_integer(value)
    end
  end
end
