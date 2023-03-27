defmodule OliWeb.Delivery.InstructorDashboard.DiscussionsLive do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  import Surface

  alias OliWeb.Components.Delivery.InstructorDashboard
  alias Oli.Resources.Collaboration
  alias OliWeb.Discussion.TableModel, as: DiscussionTableModel
  alias OliWeb.CollaborationLive.InstructorTableModel, as: CollabSpaceTableModel
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Common.Confirm

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    section = socket.assigns.section

    {:ok, discussion_table_model} = DiscussionTableModel.new([])
    {:ok, collab_space_table_model} = CollabSpaceTableModel.new([], %{}, is_listing: false)

    {:ok,
     assign(socket,
       title: section.title,
       description: section.description,
       discussion_table_model: discussion_table_model,
       collab_space_table_model: collab_space_table_model,
       limit: 10,
       filter: :all,
       offset: 0,
       count: 0,
       parent_component_id: "discussion_activity",
       section: section
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
      <%= render_modal(assigns)%>
      <InstructorDashboard.main_layout {assigns}>
        <div id={assigns[:parent_component_id]}>
          <InstructorDashboard.discussions {assigns} />
        </div>
      </InstructorDashboard.main_layout>
    """
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    push_with(socket, %{filter: filter, offset: 0})
  end

  def handle_event("paged_table_page_change", %{"offset" => offset}, socket) do
    push_with(socket, %{offset: offset})
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
      {:ok, post} ->
        socket = do_filter(socket, socket.assigns.filter, socket.assigns.offset)

        Phoenix.PubSub.broadcast(
          Oli.PubSub,
          channel_topic(socket.assigns.section, post.resource_id),
          {:post_edited, Oli.Repo.preload(post, :user)}
        )

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
      "This will also reject the replies if there are any."
    )
  end

  def handle_event("reject_post", _, socket) do
    post = Collaboration.get_post_by(%{id: socket.assigns.post_id})

    case Collaboration.delete_posts(post) do
      {number, nil} when number > 0 ->
        socket = do_filter(socket, socket.assigns.filter, socket.assigns.offset)

        Phoenix.PubSub.broadcast(
          Oli.PubSub,
          channel_topic(socket.assigns.section, post.resource_id),
          {:post_deleted, post.id}
        )

        {:noreply,
         socket
         |> hide_modal(modal_assigns: nil)}

      _ ->
        {:noreply,
         socket
         |> hide_modal(modal_assigns: nil)}
    end
  end

  def push_with(socket, attrs) do
    {:noreply,
     push_patch(
       socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           socket.assigns.section_slug,
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

  @impl true
  def handle_params(params, _, socket) do
    filter = params["filter"] || "all"
    offset = params["offset"] || 0

    socket = do_filter(socket, filter, offset)

    {:noreply, socket}
  end

  defp do_filter(socket, filter, offset) do
    %{
      :section_slug => section_slug,
      :discussion_table_model => discussion_table_model,
      :collab_space_table_model => collab_space_table_model,
      :filter => previous_filter,
      :limit => limit
    } = socket.assigns

    filter = safe_to_atom(filter)
    previous_filter = safe_to_atom(previous_filter)

    offset =
      case filter != previous_filter do
        true -> 0
        _ -> safe_to_integer(offset)
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

  defp channel_topic(section, resource_id) do
    "collab_space_#{section.slug}_#{resource_id}"
  end
end
