defmodule OliWeb.Components.Delivery.DiscussionActivity do
  use Surface.LiveComponent
  use OliWeb.Common.Modal

  alias OliWeb.Common.PagedTable
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Table.SortableTableModel
  alias Oli.Resources.Collaboration
  alias OliWeb.Discussion.TableModel, as: DiscussionTableModel
  alias OliWeb.CollaborationLive.InstructorTableModel, as: CollabSpaceTableModel
  alias OliWeb.Common.Confirm

  alias Phoenix.LiveView.JS

  prop limit, :number, default: 10
  prop filter, :string, required: true
  prop offset, :number, required: true
  prop count, :number, required: true
  prop collab_space_table_model, :struct, required: true
  prop discussion_table_model, :struct, required: true
  prop parent_component_id, :string, required: true
  prop section_slug, :string, required: true

  @default_params %{
    offset: 0,
    limit: 10,
    filter: :all
  }

  def update(assigns, socket) do
    socket =
      socket
      |> assign(
        title: assigns.section.title,
        description: assigns.section.description,
        limit: safe_to_integer(assigns.params["limit"] || @default_params.limit),
        filter: safe_to_atom(assigns.params["filter"] || @default_params.filter),
        offset: safe_to_integer(assigns.params["offset"] || @default_params.offset),
        section_slug: assigns.section.slug
      )
      |> do_filter()

    {:ok, socket}
  end

  def render(assigns) do
    ~F"""
    <div class="p-10">

      {render_modal(assigns)}

      <div class="bg-white dark:bg-gray-900 w-full">
        <h4 class="px-10 py-6 border-b border-b-gray-200 torus-h4">Discussion Activity</h4>

        <div class="flex items-end gap-2 px-10 py-6 border-b border-b-gray-200">
          <form phx-change="filter" phx-target={@myself}>
            <label class="cursor-pointer inline-flex flex-col gap-2">
              <small class="torus-small uppercase">Filter by</small>
              <select class="torus-select pr-32" name="filter">
                <option selected={@filter == :all} value="all">All</option>
                <option selected={@filter == :need_approval} value="need_approval">Posts that Need Approval</option>
                <option selected={@filter == :need_response} value="need_response">Posts Awaiting a Reply</option>
                <option selected={@filter == :by_discussion} value="by_discussion">By Discussion</option>
              </select>
            </label>
          </form>
        </div>

        <div id="discussion_activity_table">
          {#if @filter == :by_discussion}
            <PagedTable
              table_model={@collab_space_table_model}
              filter=""
              page_change={JS.push("paged_table_page_change", target: @myself)}
              total_count={@count}
              offset={@offset}
              limit={@limit}
              additional_table_class="border-0"
            />
          {#else}
            <PagedTable
              table_model={@discussion_table_model}
              filter=""
              page_change={JS.push("paged_table_page_change", target: @myself)}
              total_count={@count}
              offset={@offset}
              limit={@limit}
              additional_table_class="border-0"
            />
          {/if}
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
  def handle_event("display_accept_modal", %{"post_id" => post_id}, socket) do
    modal_assigns = %{
      title: "Accept Post",
      id: "accept_post_modal",
      ok: JS.push("accept_post", target: socket.assigns.myself),
      cancel: JS.push("cancel_confirm_modal", target: socket.assigns.myself)
    }

    display_confirm_modal(
      modal_assigns,
      "accept",
      assign(socket, post_id: post_id)
    )
  end

  @impl true
  def handle_event("accept_post", _, socket) do
    post = Collaboration.get_post_by(%{id: socket.assigns.post_id})

    case Collaboration.update_post(post, %{status: :approved}) do
      {:ok, _} ->
        {:noreply,
         do_filter(socket)
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
      ok: JS.push("reject_post", target: socket.assigns.myself),
      cancel: JS.push("cancel_confirm_modal", target: socket.assigns.myself)
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
        {:noreply,
         do_filter(socket)
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

  defp do_filter(socket) do
    %{
      :section_slug => section_slug,
      :filter => filter,
      :limit => limit,
      :offset => offset
    } = socket.assigns

    case filter do
      :by_discussion ->
        {:ok, collab_space_table_model} = CollabSpaceTableModel.new([], %{}, is_listing: false)

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
        {:ok, discussion_table_model} = DiscussionTableModel.new([], socket.assigns.myself)

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

  defp display_confirm_modal(modal_assigns, action, socket, opt_text \\ "") do
    modal = fn assigns ->
      ~F"""
      <Confirm {...@modal_assigns}>
        Are you sure you want to {action} this post? {opt_text}
      </Confirm>
      """
    end

    {:noreply,
     show_modal(
       socket,
       modal,
       modal_assigns: modal_assigns
     )}
  end
end
