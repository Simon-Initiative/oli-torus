defmodule OliWeb.CollaborationLive.CollabSpaceView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Accounts
  alias Oli.Delivery.Sections
  alias Oli.Resources
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias Oli.Resources.Collaboration.Post, as: PostSchema
  alias OliWeb.CollaborationLive.ActiveUsers
  alias OliWeb.CollaborationLive.Posts.{
    Modal,
    List,
    Sort
  }
  alias OliWeb.Common.Confirm
  alias OliWeb.Presence
  alias Phoenix.PubSub

  data selected, :string, default: ""
  data modal, :any, default: nil
  data editing_post, :struct, default: nil
  data topic, :string
  data active_users, :list
  data posts, :list
  data new_post_changeset, :changeset
  data collab_space_config, :struct
  data user, :struct
  data section, :struct
  data page_resource, :struct
  data search_params, :struct
  data sort, :struct
  data is_instructor, :boolean

  # ----------------
  def channels_topic(section_slug, resource_id),
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
    is_instructor = Map.get(session, "is_instructor", false)

    topic = channels_topic(section_slug, page_resource.id)

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
      enter_time: enter_time,
      is_instructor: is_instructor
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
                    <Sort sort={@sort} />
                  </div>
                  <button type="button" :on-click="display_create_modal" class="btn btn-primary h-25" disabled={is_archived?(@collab_space_config.status)}>+ New</button>
                </div>

                <div class="accordion mt-5 vh-100 overflow-auto" id="post-accordion">
                  <div class={if is_archived?(@collab_space_config.status), do: "readonly", else: ""}>
                    <List
                      posts={@posts}
                      collab_space_config={@collab_space_config}
                      selected={@selected}
                      user_id={@user.id}
                      is_instructor={@is_instructor} />
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

  #-----------Create Post-----------#

  def handle_event("display_create_modal", _params, socket) do
    modal_assigns = %{
      id: "create_post_modal",
      on_submit: "create_post",
      changeset: socket.assigns.new_post_changeset,
      title: "New post"
    }

    display_post_modal(modal_assigns, socket)
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

  def handle_event("create_post", %{"post" => attrs} = _params, socket) do
    socket = clear_flash(socket)

    attrs =
      if not socket.assigns.collab_space_config.auto_accept,
        do: Map.put(attrs, "status", :submitted),
        else: attrs

    case Collaboration.create_post(attrs) do
      {:ok, %PostSchema{}} ->
        socket = put_flash(socket, :info, "Post successfully created")

        PubSub.broadcast(Oli.PubSub, socket.assigns.topic, :updated_posts)

        {:noreply, hide_modal(socket, modal_assigns: nil)}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply,
          socket
          |> put_flash(:error, "Couldn't create post")
          |> hide_modal(modal_assigns: nil)}
    end
  end

  #-----------Edit Post-----------#

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

  def handle_event("edit_post", %{"post" => attrs}, socket),
    do: do_edit_post(socket.assigns.editing_post, attrs, socket)

  #-----------Delete Post-----------#

  def handle_event("display_delete_modal", %{"id" => id, "index" => index}, socket) do
    post = Collaboration.get_post_by(%{id: id})

    modal_assigns = %{
      title: "Delete Post",
      id: "delete_post_modal",
      ok: "delete_posts",
      cancel: "cancel_confirm_modal"
    }

    opt_text = if socket.assigns.is_instructor, do: "This will also delete the replies if there is any.", else: ""

    display_confirm_modal(
      modal_assigns,
      "delete",
      index,
      assign(socket, editing_post: post),
      opt_text
    )
  end

  def handle_event("delete_posts", _, socket),
    do: do_delete_post(socket.assigns.editing_post, socket)

  #-----------Archive Post-----------#

  def handle_event("display_archive_modal", %{"id" => id, "index" => index}, socket) do
    post = Collaboration.get_post_by(%{id: id})

    modal_assigns = %{
      title: "Archive Post",
      id: "archive_post_modal",
      ok: "archive_post",
      cancel: "cancel_confirm_modal"
    }

    display_confirm_modal(modal_assigns, "archive", index, assign(socket, editing_post: post))
  end

  def handle_event("archive_post", _, socket),
    do: do_edit_post(socket.assigns.editing_post, %{status: :archived}, socket)

  #-----------Unarchive Post-----------#

  def handle_event("display_unarchive_modal", %{"id" => id, "index" => index}, socket) do
    post = Collaboration.get_post_by(%{id: id})

    modal_assigns = %{
      title: "Unarchive Post",
      id: "unarchive_post_modal",
      ok: "unarchive_post",
      cancel: "cancel_confirm_modal"
    }

    display_confirm_modal(modal_assigns, "unarchive", index, assign(socket, editing_post: post))
  end

  def handle_event("unarchive_post", _, socket),
    do: do_edit_post(socket.assigns.editing_post, %{status: :approved}, socket)

  #-----------Accept Post-----------#

  def handle_event("display_accept_modal", %{"id" => id, "index" => index}, socket) do
    post = Collaboration.get_post_by(%{id: id})

    modal_assigns = %{
      title: "Accept Post",
      id: "accept_post_modal",
      ok: "accept_post",
      cancel: "cancel_confirm_modal"
    }

    display_confirm_modal(modal_assigns, "accept", index, assign(socket, editing_post: post))
  end

  def handle_event("accept_post", _, socket),
    do: do_edit_post(socket.assigns.editing_post, %{status: :approved}, socket)

  #-----------Reject Post-----------#

  def handle_event("display_reject_modal", %{"id" => id, "index" => index}, socket) do
    post = Collaboration.get_post_by(%{id: id})

    modal_assigns = %{
      title: "Reject Post",
      id: "reject_post_modal",
      ok: "reject_post",
      cancel: "cancel_confirm_modal"
    }

    display_confirm_modal(
      modal_assigns,
      "reject",
      index,
      assign(socket, editing_post: post),
      "This will also reject the replies if there is any."
    )
  end

  def handle_event("reject_post", _, socket),
    do: do_delete_post(socket.assigns.editing_post, socket)

  def handle_event("cancel_confirm_modal", _, socket) do
    {:noreply,
      socket
      |> assign(editing_post: nil)
      |> hide_modal(modal_assigns: nil)}
  end

  # ----------------

  def handle_event("set_selected", %{"id" => value}, socket),
    do: {:noreply, assign(socket, selected: value)}

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

  def handle_info(:updated_posts, socket),
    do: {:noreply, assign(socket, posts: get_posts(socket.assigns.search_params, socket.assigns.sort))}

  def handle_info(
    {:updated_collab_space_config, %CollabSpaceConfig{show_full_history: show_full_history} = collab_space_config},
    socket
  ) do
    search_params = Map.put(socket.assigns.search_params, :collab_space_config, collab_space_config)

    socket =
      if show_full_history != socket.assigns.collab_space_config.show_full_history,
        do: assign(socket, posts: get_posts(search_params, socket.assigns.sort)),
        else: socket

    {:noreply,
      assign(socket,
        collab_space_config: collab_space_config,
        search_params: search_params
      )}
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
        <Modal {...@modal_assigns} />
      """
    end

    {:noreply,
      show_modal(
        socket,
        modal,
        modal_assigns: modal_assigns
      )}
  end

  defp display_confirm_modal(modal_assigns, action, index, socket, opt_text \\ "") do
    modal = fn assigns ->
      ~F"""
        <Confirm {...@modal_assigns}> Are you sure you want to {action} post #{index}? {opt_text}</Confirm>
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
    socket = clear_flash(socket)

    case Collaboration.update_post(post, attrs) do
      {:ok, %PostSchema{}} ->
        socket = put_flash(socket, :info, "Post successfully edited")

        PubSub.broadcast(Oli.PubSub, socket.assigns.topic, :updated_posts)

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

  defp do_delete_post(post, socket) do
    socket = clear_flash(socket)

    case Collaboration.delete_posts(post) do
      {number, nil} when number > 0 ->
        socket = put_flash(socket, :info, "Post/s successfully deleted")

        PubSub.broadcast(Oli.PubSub, socket.assigns.topic, :updated_posts)

        {:noreply,
          socket
          |> assign(editing_post: nil)
          |> hide_modal(modal_assigns: nil)}

      _ ->
        {:noreply,
          socket
          |> put_flash(:error, "Couldn't delete post/s")
          |> hide_modal(modal_assigns: nil)}
    end
  end

  defp get_posts(%{
    section_id: section_id,
    resource_id: page_resource_id,
    collab_space_config: collab_space_config,
    is_instructor: true
  }, %{by: sort_by, order: sort_order}) do
    Collaboration.list_posts_for_instructor_in_page_section(section_id, page_resource_id)
    |> maybe_threading(collab_space_config)
    |> Enum.sort_by(& Map.get(&1, sort_by), sort_order)
    |> Enum.with_index(1)
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
    collab_space_config: collab_space_config
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
end
