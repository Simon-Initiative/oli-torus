defmodule OliWeb.CollaborationLive.CollabSpaceView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Accounts
  alias Oli.Delivery.Sections
  alias Oli.Resources
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias Oli.Resources.Collaboration.Post, as: PostSchema
  alias OliWeb.CollaborationLive.{
    ActiveUsers,
    PostModal,
    ShowPost,
    SortPosts
  }
  alias OliWeb.Common.Confirm
  alias OliWeb.Presence
  alias Phoenix.PubSub

  data selected, :string, default: ""
  data modal, :any, default: nil
  data editing_post, :any, default: nil
  data topic, :string
  data active_users, :list
  data posts, :list
  data new_post_changeset, :changeset
  data collab_space_config, :any
  data user, :any
  data section, :any
  data page_resource, :any
  data search_params, :any

  # ----------------
  # Presence
  def presence_topic(section_slug, resource_id),
    do: "collab_space_#{section_slug}_#{resource_id}"

  def presence_default_user_payload(user) do
    %{
      typing: false,
      first_name: user.name,
      email: user.email,
      user_id: user.id
    }
  end
  # ----------------

  def mount(
        _,
        %{
          "collab_space_config" => collab_space_config,
          "section_slug" => section_slug,
          "page_slug" => page_slug,
          "current_user_id" => current_user_id
        } = session,
        socket
      ) do
    {:ok, enter_time} = DateTime.now("Etc/UTC")

    user = Accounts.get_user_by(%{id: current_user_id})
    section = Sections.get_section_by_slug(section_slug)
    page_resource = Resources.get_resource_from_slug(page_slug)
    is_instructor = Map.get(session, "is_instructor")

    topic = presence_topic(section_slug, page_resource.id)

    PubSub.subscribe(Oli.PubSub, topic)
    Presence.track_presence(
      self(),
      topic,
      current_user_id,
      presence_default_user_payload(user)
    )

    new_post_changeset = Collaboration.change_post(%PostSchema{
      user_id: user.id,
      section_id: section.id,
      resource_id: page_resource.id
    })

    search_params = %{
      section_id: section.id,
      resource_id: page_resource.id,
      user_id: user.id,
      collab_space_config: collab_space_config,
      enter_time: enter_time
    }

    sort = %{by: :inserted_at, order: :asc}

    {:ok,
      assign(socket,
        topic: topic,
        search_params: search_params,
        page_resource: page_resource,
        section: section,
        user: user,
        active_users: Presence.list_presences(topic),
        posts: get_posts(search_params, sort),
        collab_space_config: collab_space_config,
        new_post_changeset: new_post_changeset,
        sort: sort,
        is_instructor: is_instructor
      )}
  end

  def render(assigns) do
    ~F"""
      {#if show_collab_space?(@collab_space_config)}
        {render_modal(assigns)}

        <div class="card">
          <div class="card-body d-flex align-items-center">
            <h3 class="card-title mb-0">Collaborative Space</h3>
            {#if is_archived?(@collab_space_config.status)}
              <span class="badge badge-info ml-2">Archived</span>
            {/if}
          </div>

          <div class="card-footer bg-transparent">
            <div class="row">
              <div class="col-xs-12 col-lg-9 order-lg-first">
                <div class="d-flex justify-content-between align-items-center">
                  <div class="d-flex align-items-center border border-light p-3 rounded">
                    <div class="mr-2"><strong>Sort by</strong></div>
                    <SortPosts sort={@sort} />
                  </div>
                  <button type="button" :on-click="display_create_modal" class="btn btn-primary h-25" disabled={is_archived?(@collab_space_config.status)}>+ New</button>
                </div>

                <div class="accordion mt-5 vh-100 overflow-auto" id="post-accordion">
                  <div class={if is_archived?(@collab_space_config.status), do: "readonly", else: ""}>
                    {#for {post, index} <- @posts}
                      <ShowPost
                        post={post}
                        index={index}
                        selected={@selected}
                        user={@user}
                        is_threaded={@collab_space_config.threaded}
                        is_instructor={@is_instructor}/>
                    {/for}
                  </div>
                </div>
              </div>

              <div class="col-xs-12 col-lg-3 order-first mb-5">
                <ActiveUsers users={@active_users} />
              </div>
            </div>
          </div>
        </div>
      {/if}
    """
  end

  # ----------------
  # so we can set "typing" to false
  def handle_event("_bsmodal.unmount", _, socket = %{assigns: %{topic: topic, user: %{id: user_id}}}) do
    Presence.update_presence(self(), topic, user_id, %{typing: false})
    {:noreply, assign(socket, __modal__: nil)}
  end
  use OliWeb.Common.Modal
  # ----------------

  def handle_event("display_create_modal", _params, socket) do
    modal_assigns = %{
      id: "create_post_modal",
      on_submit: "create_post",
      changeset: socket.assigns.new_post_changeset,
      title: "New post"
    }

    display_post_modal(modal_assigns, socket)
  end

  def handle_event("create_post", %{"post" => attrs} = _params, socket) do
    socket = clear_flash(socket)

    attrs =
      if not socket.assigns.collab_space_config.auto_accept,
        do: Map.put(attrs, "status", :submitted),
        else: attrs

    case Collaboration.create_post(attrs) do
      {:ok, %PostSchema{status: status}} ->
        socket = put_flash(socket, :info, "Post successfully created")

        send_updated_posts(status, socket.assigns.topic)

        {:noreply, hide_modal(socket, modal_assigns: nil)}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply,
          socket
          |> put_flash(:error, "Couldn't create post")
          |> hide_modal(modal_assigns: nil)}
    end
  end

  def handle_event("display_reply_to_post_modal", %{"parent_id" => parent_id, "index" => index}, socket) do
    post_reply_changeset =
      socket.assigns.new_post_changeset
      |> Ecto.Changeset.put_change(:parent_post_id, parent_id)
      |> Ecto.Changeset.put_change(:thread_root_id, parent_id)

    modal_assigns = %{
      id: "create_reply_modal",
      on_submit: "create_post",
      changeset: post_reply_changeset,
      title: "New reply to #{index}"
    }

    display_post_modal(modal_assigns, socket)
  end

  def handle_event(
        "display_reply_to_reply_modal",
        %{"parent_id" => parent_id, "root_id" => root_id, "index" => index},
        socket
      ) do
    reply_reply_changeset =
      socket.assigns.new_post_changeset
      |> Ecto.Changeset.put_change(:parent_post_id, parent_id)
      |> Ecto.Changeset.put_change(:thread_root_id, root_id)

    modal_assigns = %{
      id: "create_reply_modal",
      on_submit: "create_post",
      changeset: reply_reply_changeset,
      title: "New reply to #{index}"
    }

    display_post_modal(modal_assigns, socket)
  end

  def handle_event("display_edit_modal", %{"id" => id}, socket) do
    post = Collaboration.get_post_by(%{id: id})
    changeset = Collaboration.change_post(post)

    modal_assigns = %{
      id: "edit_post_modal",
      on_submit: "edit_post",
      changeset: changeset
    }

    display_post_modal(modal_assigns, assign(socket, editing_post: post))
  end

  def handle_event("edit_post", %{"post" => attrs}, socket) do
    socket = clear_flash(socket)

    do_edit_post(socket.assigns.editing_post, attrs, socket)
  end

  def handle_event("display_delete_modal", %{"id" => id, "index" => index}, socket) do
    post = Collaboration.get_post_by(%{id: id})

    modal_assigns = %{
      title: "Delete Post",
      id: "delete_post_modal",
      ok: "delete_post",
      cancel: "cancel_delete_post"
    }

    modal = fn assigns ->
      ~F"""
        <Confirm {...@modal_assigns}>Are you sure you want to delete the post #{index}?</Confirm>
      """
    end

    {:noreply,
      socket
      |> assign(editing_post: post)
      |> show_modal(
        modal,
        modal_assigns: modal_assigns
      )}
  end

  def handle_event("delete_post", _, socket) do
    socket = clear_flash(socket)

    do_edit_post(socket.assigns.editing_post, %{status: :deleted}, socket)
  end

  def handle_event("cancel_delete_post", _, socket) do
    {:noreply,
      socket
      |> assign(editing_post: nil)
      |> hide_modal(modal_assigns: nil)}
  end

  def handle_event("display_archive_modal", %{"id" => id, "index" => index, "status" => status}, socket) do
    post = Collaboration.get_post_by(%{id: id})
    status = String.to_atom(status)

    modal_assigns = %{
      title: is_archived?(status) && "Unarchive Post" || "Archive Post",
      id: "archive_post_modal",
      ok: "archive_post",
      cancel: "cancel_archive_post"
    }

    modal = fn assigns ->
      ~F"""
        <Confirm {...@modal_assigns}>Are you sure you want to {is_archived?(status) && "unarchive" || "archive"} the post #{index}?</Confirm>
      """
    end

    {:noreply,
      socket
      |> assign(archived_post: post, post_status: is_archived?(status) && :approved || :archived)
      |> show_modal(
        modal,
        modal_assigns: modal_assigns
      )}
  end

  def handle_event("archive_post", _, socket) do
    socket = clear_flash(socket)

    do_edit_post(socket.assigns.archived_post, %{status: socket.assigns.post_status}, socket)
  end

  def handle_event("cancel_archive_post", _, socket) do
    {:noreply,
      socket
      |> assign(archived_post: nil)
      |> hide_modal(modal_assigns: nil)}
  end

  def handle_event("set_selected", %{"id" => value}, socket) do
    {:noreply, assign(socket, selected: value)}
  end

  def handle_event("sort", %{"sort" => %{"sort_by" => sort_by, "sort_order" => sort_order}} = _params, socket) do
    sort_by = String.to_atom(sort_by)
    sort_order = String.to_atom(sort_order)

    sorted_posts =
      socket.assigns.posts
      |> Enum.unzip()
      |> elem(0)
      |> Enum.sort_by(& Map.get(&1, sort_by), sort_order)
      |> Enum.with_index(1)

    {:noreply,
      assign(
        socket,
        posts: sorted_posts,
        sort: %{by: sort_by, order: sort_order}
      )}
  end

  def handle_info(:updated_posts, socket) do
    {:noreply, assign(socket, posts: get_posts(socket.assigns.search_params, socket.assigns.sort))}
  end

  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply,
      assign(socket,
        active_users: Presence.list_presences(socket.assigns.topic)
      )}
  end

  defp display_post_modal(modal_assigns, socket = %{assigns: %{topic: topic, user: %{id: user_id}}}) do
    Presence.update_presence(self(), topic, user_id, %{typing: true})

    modal = fn assigns ->
      ~F"""
        <PostModal {...@modal_assigns} />
      """
    end

    {:noreply,
      show_modal(
        socket,
        modal,
        modal_assigns: modal_assigns
      )}
  end

  defp do_edit_post(post, attrs, socket) do
    case Collaboration.update_post(post, attrs) do
      {:ok, %PostSchema{status: status}} ->
        socket = put_flash(socket, :info, "Post successfully edited")

        send_updated_posts(status, socket.assigns.topic)

        {:noreply,
          socket
          |> assign(editing_post: nil)
          |> hide_modal(modal_assigns: nil)}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply,
          socket
          |> put_flash(:error, "Couldn't edit post")
          |> hide_modal(modal_assigns: nil)}
    end
  end

  defp get_posts(%{
    section_id: section_id,
    resource_id: page_resource_id,
    user_id: user_id,
    collab_space_config: %CollabSpaceConfig{show_full_history: false} = collab_space_config,
    enter_time: enter_time
  }, %{by: sort_by, order: sort_order}) do
    Collaboration.list_posts_for_user_in_page_section(section_id, page_resource_id, user_id, enter_time)
    |> maybe_threading(collab_space_config)
    |> Enum.sort_by(& Map.get(&1, sort_by), sort_order)
    |> Enum.with_index(1)
  end

  defp get_posts(%{
    section_id: section_id,
    resource_id: page_resource_id,
    user_id: user_id,
    collab_space_config: collab_space_config,
  }, %{by: sort_by, order: sort_order}) do
    Collaboration.list_posts_for_user_in_page_section(section_id, page_resource_id, user_id)
    |> maybe_threading(collab_space_config)
    |> Enum.sort_by(& Map.get(&1, sort_by), sort_order)
    |> Enum.with_index(1)
  end

  defp maybe_threading(all_posts, %CollabSpaceConfig{threaded: true}) do
    Enum.reduce(all_posts, [], fn post, acc ->
      if is_nil(post.thread_root_id) do
        replies =
          all_posts
          |> Enum.filter(fn child -> child.thread_root_id == post.id end)
          |> Enum.with_index(1)

        acc ++ [Map.put(post, :replies, replies)]
      else
        acc
      end
    end)
  end
  defp maybe_threading(all_posts, _), do: all_posts

  defp show_collab_space?(nil), do: false
  defp show_collab_space?(%CollabSpaceConfig{status: :disabled}), do: false
  defp show_collab_space?(_), do: true

  defp is_archived?(:archived), do: true
  defp is_archived?(_), do: false

  defp send_updated_posts(:submitted, _), do: send(self(), :updated_posts)
  defp send_updated_posts(_, topic), do: PubSub.broadcast(Oli.PubSub, topic, :updated_posts)
end
