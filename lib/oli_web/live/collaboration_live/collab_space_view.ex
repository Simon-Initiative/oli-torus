defmodule OliWeb.CollaborationLive.CollabSpaceView do
  use OliWeb, :live_view

  alias Phoenix.LiveView.JS

  alias Oli.Accounts
  alias Oli.Accounts.{User}
  alias Oli.Delivery.Sections
  alias Oli.Resources
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias Oli.Resources.Collaboration.Post, as: PostSchema

  alias Oli.Repo
  alias OliWeb.CollaborationLive.ActiveUsers
  alias OliWeb.CollaborationLive.Posts.Sort
  alias OliWeb.CollaborationLive.Posts.List, as: PostList
  alias OliWeb.Presence
  alias Phoenix.PubSub
  alias OliWeb.Components.Delivery.Buttons
  alias OliWeb.Components.Modal

  # ----------------
  def channels_topic(section_slug, resource_id),
    do: "collab_space_#{section_slug}_#{resource_id}"

  def presence_default_user_payload(user) do
    %{
      typing: false,
      first_name: user.name,
      email: user.email,
      user_id: user.id,
      is_guest: is_guest(user)
    }
  end

  defp is_guest(%User{guest: guest}), do: guest
  defp is_guest(_), do: false

  # ----------------

  def mount(
        _,
        %{
          "collab_space_config" => collab_space_config,
          "section_slug" => section_slug,
          "resource_slug" => resource_slug
        } = session,
        socket
      ) do
    {:ok, enter_time} = DateTime.now("Etc/UTC")

    {user, user_id} =
      case Map.get(session, "current_user_id") do
        nil ->
          id = Map.get(session, "current_author_id")
          {Accounts.get_author(id), id}

        id ->
          {Accounts.get_user_by(%{id: id}), id}
      end

    section = Sections.get_section_by_slug(section_slug)
    resource = Resources.get_resource_from_slug(resource_slug)
    is_instructor = Map.get(session, "is_instructor", false)
    is_student = Map.get(session, "is_student", false)

    title = Map.get(session, "title", "Discussion")

    topic = channels_topic(section_slug, resource.id)

    PubSub.subscribe(Oli.PubSub, topic)

    Presence.track_presence(
      self(),
      topic,
      user_id,
      presence_default_user_payload(user)
    )

    new_post_changeset =
      Collaboration.change_post(%PostSchema{
        user_id: user.id,
        section_id: section.id,
        resource_id: resource.id
      })

    search_params = %{
      section_id: section.id,
      resource_id: resource.id,
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
       resource: resource,
       section: section,
       user: user,
       active_users: Presence.list_presences(topic),
       posts: get_posts(search_params, sort),
       collab_space_config: collab_space_config,
       new_post_form: to_form(new_post_changeset),
       sort: sort,
       is_instructor: is_instructor,
       is_student: is_student,
       title: title,
       selected: "",
       editing_post: nil,
       is_edition_mode: false,
       modal_assigns: %{}
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto">
      <Modal.modal
        id="delete_post_modal"
        on_confirm={JS.push("delete_posts") |> Modal.hide_modal("delete_post_modal")}
        on_cancel={JS.push("cancel_confirm_modal")}
      >
        <:title>Delete Post</:title>
        {"Are you sure you want to delete post #{@modal_assigns[:index]}?"}
        <:confirm>OK</:confirm>
        <:cancel>Cancel</:cancel>
      </Modal.modal>

      <Modal.modal
        id="archive_post_modal"
        on_confirm={JS.push("archive_post") |> Modal.hide_modal("archive_post_modal")}
        on_cancel={JS.push("cancel_confirm_modal")}
      >
        <:title>Archive Post</:title>
        {"Are you sure you want to archive post #{@modal_assigns[:index]}?"}
        <:confirm>OK</:confirm>
        <:cancel>Cancel</:cancel>
      </Modal.modal>

      <Modal.modal
        id="unarchive_post_modal"
        on_confirm={JS.push("unarchive_post") |> Modal.hide_modal("unarchive_post_modal")}
        on_cancel={JS.push("cancel_confirm_modal")}
      >
        <:title>Unarchive Post</:title>
        {"Are you sure you want to unarchive post #{@modal_assigns[:index]}?"}
        <:confirm>OK</:confirm>
        <:cancel>Cancel</:cancel>
      </Modal.modal>

      <Modal.modal
        id="accept_post_modal"
        on_confirm={JS.push("accept_post") |> Modal.hide_modal("accept_post_modal")}
        on_cancel={JS.push("cancel_confirm_modal")}
      >
        <:title>Accept Post</:title>
        {"Are you sure you want to accept post #{@modal_assigns[:index]}?"}
        <:confirm>OK</:confirm>
        <:cancel>Cancel</:cancel>
      </Modal.modal>

      <Modal.modal
        id="reject_post_modal"
        on_confirm={JS.push("reject_post") |> Modal.hide_modal("reject_post_modal")}
        on_cancel={JS.push("cancel_confirm_modal")}
      >
        <:title>Reject Post</:title>
        {"Are you sure you want to reject post #{@modal_assigns[:index]}? This will also reject the replies if there is any."}
        <:confirm>OK</:confirm>
        <:cancel>Cancel</:cancel>
      </Modal.modal>

      <div class="bg-white dark:bg-gray-800 dark:text-delivery-body-color-dark shadow">
        <div class="flex items-center justify-between p-5 w-full">
          <h3 class="text-xl font-bold">{@title}</h3>
          <span :if={is_archived?(@collab_space_config.status)} class="badge badge-info ml-2">
            Archived
          </span>
        </div>

        <.form
          :if={!is_archived?(@collab_space_config.status)}
          id="new_post_form"
          for={@new_post_form}
          phx-submit="create_post"
          class="bg-gray-100 dark:bg-gray-700 mb-5 m-3 p-3 rounded-sm"
        >
          <div class="hidden">
            <.input type="hidden" field={@new_post_form[:user_id]} />
            <.input type="hidden" field={@new_post_form[:section_id]} />
            <.input type="hidden" field={@new_post_form[:resource_id]} />
            <.input type="hidden" field={@new_post_form[:parent_post_id]} />
            <.input type="hidden" field={@new_post_form[:thread_root_id]} />
          </div>

          <.inputs_for :let={pc} field={@new_post_form[:content]}>
            <.input
              type="textarea"
              field={pc[:message]}
              autocomplete="off"
              placeholder="New post"
              data-grow="true"
              data-initial-height={44}
              onkeyup="resizeTextArea(this)"
              class="torus-input border-r-0 collab-space__textarea"
            />
          </.inputs_for>

          <div class="flex justify-end">
            <%= if @is_student and @collab_space_config.anonymous_posting do %>
              <div class="hidden">
                <.input
                  type="checkbox"
                  id="new_post_anonymous_checkbox"
                  field={@new_post_form[:anonymous]}
                />
              </div>
              <Buttons.button_with_options
                id="create_post_button"
                type="submit"
                options={[
                  %{
                    text: "Post anonymously",
                    on_click:
                      JS.dispatch("click", to: "#new_post_anonymous_checkbox")
                      |> JS.dispatch("click", to: "#create_post_button_button")
                  }
                ]}
              >
                Create Post
              </Buttons.button_with_options>
            <% else %>
              <Buttons.button disabled={is_archived?(@collab_space_config.status)} type="submit">
                Create Post
              </Buttons.button>
            <% end %>
          </div>
        </.form>

        <div :if={length(@posts) > 1} class="flex justify-end gap-2 py-2 px-5">
          <Sort.render sort={@sort} />
        </div>
        <div
          :if={length(@posts) == 0}
          class="border border-gray-100 rounded-sm p-5 flex items-center justify-center m-2"
        >
          <span class="torus-span">No posts yet</span>
        </div>

        <PostList.render
          posts={@posts}
          collab_space_config={@collab_space_config}
          selected={@selected}
          user_id={@user.id}
          is_instructor={@is_instructor}
          is_student={@is_student}
          editing_post={if @is_edition_mode, do: @editing_post, else: nil}
        />

        <div class="p-5">
          <ActiveUsers.render users={@active_users} />
        </div>
      </div>
    </div>
    """
  end

  # ----------------
  # so we can set "typing" to false

  def handle_event(
        "phx_modal.unmount",
        _,
        socket = %{assigns: %{topic: topic, user: %{id: user_id}}}
      ) do
    Presence.update_presence(self(), topic, user_id, %{typing: false})
    {:noreply, assign(socket, __modal__: nil)}
  end

  # ----------------

  def handle_event("create_post", %{"post" => attrs} = _params, socket) do
    socket = clear_flash(socket)

    attrs =
      if not socket.assigns.collab_space_config.auto_accept and
           socket.assigns.is_student,
         do: Map.put(attrs, "status", :submitted),
         else: attrs

    case Collaboration.create_post(attrs) do
      {:ok, %PostSchema{} = post} ->
        socket = put_flash(socket, :info, "Post successfully created")

        PubSub.broadcast(
          Oli.PubSub,
          socket.assigns.topic,
          {:post_created, Repo.preload(post, :user), socket.assigns.user.id}
        )

        {:noreply, assign(socket, modal_assigns: nil)}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Couldn't create post")
         |> assign(modal_assigns: nil)}
    end
  end

  # -----------Edit Post-----------#
  def handle_event("set_editing_post", %{"post_id" => post_id}, socket) do
    editing_post = socket.assigns.editing_post

    {is_edition_mode, post} =
      case editing_post && Integer.to_string(editing_post.id) == post_id do
        true -> {false, nil}
        _ -> {true, Collaboration.get_post_by(%{id: post_id})}
      end

    socket = assign(socket, editing_post: post, is_edition_mode: is_edition_mode)

    {:noreply, push_event(socket, "set_focus", %{id: "post_text_area_#{post_id}"})}
  end

  def handle_event("edit_post", %{"post" => attrs}, socket),
    do: do_edit_post(socket.assigns.editing_post, attrs, socket)

  # -----------Delete Post-----------#
  def handle_event(
        "display_delete_modal",
        %{"id" => id, "index" => index},
        socket
      ) do
    post = Collaboration.get_post_by(%{id: id})

    {:noreply,
     assign(socket,
       editing_post: post,
       is_edition_mode: false,
       modal_assigns: %{index: index}
     )
     |> clear_flash()}
  end

  def handle_event("delete_posts", _, socket),
    do: do_delete_post(socket.assigns.editing_post, socket)

  # -----------Archive Post-----------#

  def handle_event(
        "display_archive_modal",
        %{"id" => id, "index" => index},
        socket
      ) do
    post = Collaboration.get_post_by(%{id: id})

    {:noreply,
     assign(socket,
       editing_post: post,
       is_edition_mode: false,
       modal_assigns: %{index: index}
     )}
  end

  def handle_event("archive_post", _, socket),
    do: do_edit_post(socket.assigns.editing_post, %{status: :archived}, socket)

  # -----------Unarchive Post-----------#

  def handle_event(
        "display_unarchive_modal",
        %{"id" => id, "index" => index},
        socket
      ) do
    post = Collaboration.get_post_by(%{id: id})

    {:noreply,
     assign(socket,
       editing_post: post,
       is_edition_mode: false,
       modal_assigns: %{index: index}
     )}
  end

  def handle_event("unarchive_post", _, socket),
    do: do_edit_post(socket.assigns.editing_post, %{status: :approved}, socket)

  # -----------Accept Post-----------#

  def handle_event(
        "display_accept_modal",
        %{"id" => id, "index" => index},
        socket
      ) do
    post = Collaboration.get_post_by(%{id: id})

    {:noreply,
     assign(socket,
       editing_post: post,
       is_edition_mode: false,
       modal_assigns: %{index: index}
     )}
  end

  def handle_event("accept_post", _, socket),
    do: do_edit_post(socket.assigns.editing_post, %{status: :approved}, socket)

  # -----------Reject Post-----------#

  def handle_event(
        "display_reject_modal",
        %{"id" => id, "index" => index},
        socket
      ) do
    post = Collaboration.get_post_by(%{id: id})

    {:noreply,
     assign(socket,
       editing_post: post,
       is_edition_mode: false,
       modal_assigns: %{index: index}
     )}
  end

  def handle_event("reject_post", _, socket),
    do: do_delete_post(socket.assigns.editing_post, socket)

  def handle_event("cancel_confirm_modal", _, socket) do
    {
      :noreply,
      socket
      |> assign(editing_post: nil)
      |> assign(modal_assigns: nil)
    }
  end

  # ----------------

  def handle_event("set_selected", %{"id" => value}, socket) do
    socket = clear_flash(socket)

    # we mark the expanded post replies as read
    socket.assigns.posts
    |> Enum.find(fn {post, _} -> post.id == String.to_integer(value) end)
    |> then(fn {expanded_post, _} -> expanded_post end)
    |> mark_replies_as_read(socket.assigns.user.id)

    {:noreply, assign(socket, selected: (socket.assigns.selected != value && value) || nil)}
  end

  def handle_event(
        "sort",
        %{"sort_by" => sort_by, "sort_order" => sort_order},
        socket
      ) do
    socket = clear_flash(socket)
    sort_by = String.to_atom(sort_by)
    sort_order = String.to_atom(sort_order)

    sorted_posts =
      socket.assigns.posts
      |> Enum.unzip()
      |> elem(0)
      |> sort(sort_by, sort_order)
      |> Enum.with_index(1)

    {:noreply,
     assign(
       socket,
       posts: sorted_posts,
       sort: %{by: sort_by, order: sort_order}
     )}
  end

  def handle_info({:post_created, %PostSchema{} = post, created_by_id}, socket) do
    all_posts = get_all_posts(socket.assigns.posts)

    posts =
      if post.status == :submitted do
        if socket.assigns.is_instructor or
             post.user.id == socket.assigns.user.id,
           do: all_posts ++ [post],
           else: all_posts
      else
        all_posts ++ [post]
      end

    {:noreply,
     assign(socket,
       posts: get_posts(socket.assigns.search_params, socket.assigns.sort, posts)
     )
     |> maybe_clear_flash(created_by_id, socket.assigns.user.id)}
  end

  def handle_info({:post_deleted, post_id, deleted_by_id}, socket) do
    posts =
      socket.assigns.posts
      |> get_all_posts()
      |> Enum.filter(fn post ->
        post.id != post_id and post.thread_root_id != post_id and
          post.parent_post_id != post_id
      end)

    {:noreply,
     assign(socket,
       posts: get_posts(socket.assigns.search_params, socket.assigns.sort, posts)
     )
     |> maybe_clear_flash(deleted_by_id, socket.assigns.user.id)}
  end

  def handle_info({:post_edited, %PostSchema{} = post_edited, edited_by_id}, socket) do
    all_posts = get_all_posts(socket.assigns.posts)

    posts =
      if post_edited.status == :submitted do
        if socket.assigns.is_instructor or
             post_edited.user.id == socket.assigns.user.id,
           do: update_in_all_posts(all_posts, post_edited),
           else: all_posts
      else
        case Enum.find(all_posts, &(&1.id == post_edited.id)) do
          nil -> all_posts ++ [post_edited]
          _ -> update_in_all_posts(all_posts, post_edited)
        end
      end

    {:noreply,
     assign(socket,
       posts: get_posts(socket.assigns.search_params, socket.assigns.sort, posts)
     )
     |> maybe_clear_flash(edited_by_id, socket.assigns.user.id)}
  end

  def handle_info(
        {:updated_collab_space_config,
         %CollabSpaceConfig{show_full_history: show_full_history} = collab_space_config},
        socket
      ) do
    search_params =
      Map.put(
        socket.assigns.search_params,
        :collab_space_config,
        collab_space_config
      )

    socket =
      if show_full_history !=
           socket.assigns.collab_space_config.show_full_history,
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
     )
     |> clear_flash()}
  end

  defp do_edit_post(post, attrs, socket) do
    socket = clear_flash(socket)

    case Collaboration.update_post(post, attrs) do
      {:ok, %PostSchema{} = post} ->
        socket =
          if attrs[:status] == :approved do
            clear_flash(socket)
          else
            put_flash(socket, :info, "Post successfully edited")
          end

        PubSub.broadcast(
          Oli.PubSub,
          socket.assigns.topic,
          {:post_edited, Repo.preload(post, :user), socket.assigns.user.id}
        )

        {:noreply,
         socket
         |> assign(editing_post: nil)
         |> assign(modal_assigns: nil)}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Couldn't edit post")
         |> assign(modal_assigns: nil)}
    end
  end

  defp do_delete_post(post, socket) do
    socket = clear_flash(socket)

    case Collaboration.delete_posts(post) do
      {number, nil} when number > 0 ->
        socket = put_flash(socket, :info, "Post/s successfully deleted")

        PubSub.broadcast(
          Oli.PubSub,
          socket.assigns.topic,
          {:post_deleted, post.id, socket.assigns.user.id}
        )

        {:noreply,
         socket
         |> assign(editing_post: nil)
         |> assign(modal_assigns: nil)}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Couldn't delete post/s")
         |> assign(modal_assigns: nil)}
    end
  end

  defp get_posts(
         %{
           section_id: section_id,
           resource_id: resource_id,
           user_id: user_id,
           collab_space_config: collab_space_config,
           is_instructor: true
         },
         %{by: sort_by, order: sort_order}
       ) do
    Collaboration.list_posts_for_instructor_in_page_section(
      section_id,
      resource_id
    )
    |> mark_root_posts_as_read(user_id)
    |> maybe_threading(collab_space_config)
    |> sort(sort_by, sort_order)
    |> Enum.with_index(1)
  end

  defp get_posts(
         %{
           section_id: section_id,
           resource_id: resource_id,
           user_id: user_id,
           collab_space_config:
             %CollabSpaceConfig{show_full_history: false} = collab_space_config,
           enter_time: enter_time
         },
         %{by: sort_by, order: sort_order}
       ) do
    Collaboration.list_posts_for_user_in_page_section(
      section_id,
      resource_id,
      user_id,
      enter_time
    )
    |> mark_root_posts_as_read(user_id)
    |> maybe_threading(collab_space_config)
    |> sort(sort_by, sort_order)
    |> Enum.with_index(1)
  end

  defp get_posts(
         %{
           section_id: section_id,
           resource_id: resource_id,
           user_id: user_id,
           collab_space_config: collab_space_config
         },
         %{by: sort_by, order: sort_order}
       ) do
    Collaboration.list_posts_for_user_in_page_section(
      section_id,
      resource_id,
      user_id
    )
    |> mark_root_posts_as_read(user_id)
    |> maybe_threading(collab_space_config)
    |> sort(sort_by, sort_order)
    |> Enum.with_index(1)
  end

  defp get_posts(
         %{user_id: user_id, collab_space_config: collab_space_config},
         %{by: sort_by, order: sort_order},
         posts
       ) do
    posts
    |> mark_root_posts_as_read(user_id)
    |> maybe_threading(collab_space_config)
    |> sort(sort_by, sort_order)
    |> Enum.with_index(1)
  end

  _docp =
    "when the user enters the page, we asume that all the posts (thread root posts) shown are read"

  defp mark_root_posts_as_read(posts, user_id) do
    posts
    |> Enum.filter(fn post -> is_nil(post.parent_post_id) end)
    |> Collaboration.mark_posts_as_read(user_id, true)

    posts
  end

  _docp =
    "this funciton will be called when a user expands a thread root post, to mark all replies as read asynchronously"

  defp mark_replies_as_read(expanded_post, user_id) do
    Enum.reduce(expanded_post.replies, [], fn {reply, _}, acc_replies ->
      [reply | acc_replies]
    end)
    |> Collaboration.mark_posts_as_read(user_id, true)
  end

  defp maybe_threading(all_posts, %CollabSpaceConfig{threaded: true}) do
    posts_mapper =
      all_posts
      |> Enum.group_by(fn post -> post.parent_post_id end)

    Map.get(posts_mapper, nil, [])
    |> Enum.map(fn root_post ->
      replies =
        build_replies([root_post], posts_mapper, 1, [])
        |> Enum.with_index(1)

      root_post
      |> Map.put(:replies, replies)
      |> Map.put(:replies_count, length(replies))
      |> Map.put(:post_level, 0)
    end)
  end

  defp maybe_threading(all_posts, _), do: all_posts

  defp build_replies([], _mapper, _post_level, acum_replies), do: List.flatten(acum_replies)

  defp build_replies([reply | replies], mapper, post_level, acum_replies) do
    post_full_replies =
      Enum.map(Map.get(mapper, reply.id, []), fn r ->
        [Map.put(r, :post_level, post_level) | build_replies([r], mapper, post_level + 1, [])]
      end)

    build_replies(replies, mapper, post_level, [post_full_replies | acum_replies])
  end

  defp is_archived?(:archived), do: true
  defp is_archived?(_), do: false

  defp sort(posts, :inserted_at = sort_by, sort_order) do
    Enum.sort_by(
      posts,
      &(Map.get(&1, sort_by) |> DateTime.to_unix()),
      sort_order
    )
  end

  defp sort(posts, sort_by, sort_order) do
    Enum.sort_by(posts, &Map.get(&1, sort_by), sort_order)
  end

  defp update_in_all_posts(posts, %PostSchema{id: post_edited_id} = post_edited) do
    Enum.map(posts, fn
      %PostSchema{id: ^post_edited_id} -> post_edited
      post -> post
    end)
  end

  defp get_all_posts(posts) do
    posts
    |> Enum.unzip()
    |> elem(0)
    |> Enum.reduce([], fn post, acc ->
      replies =
        post
        |> Map.get(:replies, [])
        |> Enum.unzip()
        |> elem(0)

      acc ++ [post] ++ replies
    end)
  end

  defp maybe_clear_flash(socket, owner_id, current_user_id) do
    if owner_id != current_user_id do
      clear_flash(socket)
    else
      socket
    end
  end
end
