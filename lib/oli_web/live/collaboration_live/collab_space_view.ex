defmodule OliWeb.CollaborationLive.CollabSpaceView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Accounts
  alias Oli.Delivery.Sections
  alias Oli.Resources
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias Oli.Resources.Collaboration.Post, as: PostSchema

  alias Oli.Repo
  alias OliWeb.CollaborationLive.ActiveUsers
  alias OliWeb.CollaborationLive.Posts.Sort
  alias OliWeb.CollaborationLive.Posts.List, as: PostList
  alias OliWeb.Common.Confirm
  alias OliWeb.Presence
  alias Phoenix.PubSub

  alias Surface.Components.Form

  alias Surface.Components.Form.{
    Field,
    TextArea,
    Inputs,
    HiddenInput,
    Checkbox,
    Label
  }

  data selected, :string, default: ""
  data modal, :any, default: nil

  data editing_post, :struct, default: nil
  data is_edition_mode, :boolean, default: false
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
  data is_instructor, :boolean, default: false
  data is_student, :boolean, default: false

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
          "is_instructor" => is_instructor,
          "is_student" => is_student
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
    page_resource = Resources.get_resource_from_slug(page_slug)

    topic = channels_topic(section_slug, page_resource.id)

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
       is_instructor: is_instructor,
       is_student: is_student
     )}
  end

  def render(assigns) do
    ~F"""
    {render_modal(assigns)}

    <div class="bg-white dark:bg-gray-800 dark:text-delivery-body-color-dark shadow">
      <div>
        <div class="flex items-center justify-between p-5">
          <div class="flex items-center justify-between w-full">
            <h3 class="text-xl font-bold">Discussion</h3>
            {#if is_archived?(@collab_space_config.status)}
              <span class="badge badge-info ml-2">Archived</span>
            {/if}
          </div>
        </div>
      </div>

      <div class="p-2 pt-0 mb-5">
        <Form
          id="new_post_form"
          for={@new_post_changeset}
          submit="create_post"
          opts={autocomplete: "off"}
          class="bg-gray-100 p-3 rounded-sm"
        >
          <HiddenInput field={:user_id} />
          <HiddenInput field={:section_id} />
          <HiddenInput field={:resource_id} />

          <HiddenInput field={:parent_post_id} />
          <HiddenInput field={:thread_root_id} />

          <Inputs for={:content}>
            <Field name={:message}>
              <TextArea
                opts={
                  placeholder: "New post",
                  "data-grow": "true",
                  "data-initial-height": 44,
                  onkeyup: "resizeTextArea(this)"
                }
                class="torus-input border-r-0 collab-space__textarea"
              />
            </Field>
          </Inputs>
          <div class="flex flex-col items-end">
            <button
                  disabled={is_archived?(@collab_space_config.status)}
                  type="submit"
                  class="torus-button primary"
            >Create Post</button>
            {#if @is_student}
              <Field>
                <Checkbox field={:anonymous} />
                <Label class="text-xs" text="Anonymous"/>
              </Field>
            {/if}
          </div>
        </Form>
      </div>

      {#if length(@posts) > 1}
        <div class="flex justify-end gap-2 py-2 px-5">
          <Sort sort={@sort} />
        </div>
      {#elseif length(@posts) == 0}
        <div class="border border-gray-100 rounded-sm p-5 flex items-center justify-center m-2">
          <span class="torus-span">No posts yet</span>
        </div>
      {/if}

      <div class={if is_archived?(@collab_space_config.status), do: "readonly", else: ""}>
        <PostList
          posts={@posts}
          collab_space_config={@collab_space_config}
          selected={@selected}
          user_id={@user.id}
          is_instructor={@is_instructor}
          is_student={@is_student}
          editing_post={if @is_edition_mode, do: @editing_post, else: nil}
        />
      </div>

      <div class="p-5">
        <ActiveUsers users={@active_users} />
      </div>
    </div>
    """
  end

  # ----------------
  # so we can set "typing" to false

  def handle_event(
        "_bsmodal.unmount",
        _,
        socket = %{assigns: %{topic: topic, user: %{id: user_id}}}
      ) do
    Presence.update_presence(self(), topic, user_id, %{typing: false})
    {:noreply, assign(socket, __modal__: nil)}
  end

  use OliWeb.Common.Modal
  # ----------------

  def handle_event("create_post", %{"post" => attrs} = _params, socket) do
    socket = clear_flash(socket)

    attrs =
      if not socket.assigns.collab_space_config.auto_accept,
        do: Map.put(attrs, "status", :submitted),
        else: attrs

    case Collaboration.create_post(attrs) do
      {:ok, %PostSchema{} = post} ->
        socket = put_flash(socket, :info, "Post successfully created")

        PubSub.broadcast(
          Oli.PubSub,
          socket.assigns.topic,
          {:post_created, Repo.preload(post, :user)}
        )

        {:noreply, hide_modal(socket, modal_assigns: nil)}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Couldn't create post")
         |> hide_modal(modal_assigns: nil)}
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
  def handle_event("display_delete_modal", %{"id" => id, "index" => index}, socket) do
    post = Collaboration.get_post_by(%{id: id})

    modal_assigns = %{
      title: "Delete Post",
      id: "delete_post_modal",
      ok: "delete_posts",
      cancel: "cancel_confirm_modal"
    }

    opt_text =
      if socket.assigns.is_instructor,
        do: "This will also delete the replies if there is any.",
        else: ""

    display_confirm_modal(
      modal_assigns,
      "delete",
      index,
      assign(socket, editing_post: post, is_edition_mode: false),
      opt_text
    )
  end

  def handle_event("delete_posts", _, socket),
    do: do_delete_post(socket.assigns.editing_post, socket)

  # -----------Archive Post-----------#

  def handle_event("display_archive_modal", %{"id" => id, "index" => index}, socket) do
    post = Collaboration.get_post_by(%{id: id})

    modal_assigns = %{
      title: "Archive Post",
      id: "archive_post_modal",
      ok: "archive_post",
      cancel: "cancel_confirm_modal"
    }

    display_confirm_modal(
      modal_assigns,
      "archive",
      index,
      assign(socket, editing_post: post, is_edition_mode: false)
    )
  end

  def handle_event("archive_post", _, socket),
    do: do_edit_post(socket.assigns.editing_post, %{status: :archived}, socket)

  # -----------Unarchive Post-----------#

  def handle_event("display_unarchive_modal", %{"id" => id, "index" => index}, socket) do
    post = Collaboration.get_post_by(%{id: id})

    modal_assigns = %{
      title: "Unarchive Post",
      id: "unarchive_post_modal",
      ok: "unarchive_post",
      cancel: "cancel_confirm_modal"
    }

    display_confirm_modal(
      modal_assigns,
      "unarchive",
      index,
      assign(socket, editing_post: post, is_edition_mode: false)
    )
  end

  def handle_event("unarchive_post", _, socket),
    do: do_edit_post(socket.assigns.editing_post, %{status: :approved}, socket)

  # -----------Accept Post-----------#

  def handle_event("display_accept_modal", %{"id" => id, "index" => index}, socket) do
    post = Collaboration.get_post_by(%{id: id})

    modal_assigns = %{
      title: "Accept Post",
      id: "accept_post_modal",
      ok: "accept_post",
      cancel: "cancel_confirm_modal"
    }

    display_confirm_modal(
      modal_assigns,
      "accept",
      index,
      assign(socket, editing_post: post, is_edition_mode: false)
    )
  end

  def handle_event("accept_post", _, socket),
    do: do_edit_post(socket.assigns.editing_post, %{status: :approved}, socket)

  # -----------Reject Post-----------#

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
      assign(socket, editing_post: post, is_edition_mode: false),
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

  def handle_event("set_selected", %{"id" => value}, socket) do
    socket = clear_flash(socket)

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

  def handle_info({:post_created, %PostSchema{} = post}, socket) do
    all_posts = get_all_posts(socket.assigns.posts)

    posts =
      if post.status == :submitted do
        if socket.assigns.is_instructor or post.user.id == socket.assigns.user.id,
          do: all_posts ++ [post],
          else: all_posts
      else
        all_posts ++ [post]
      end

    {:noreply,
     assign(socket,
       posts: get_posts(socket.assigns.search_params, socket.assigns.sort, posts)
     )}
  end

  def handle_info({:post_deleted, post_id}, socket) do
    posts =
      socket.assigns.posts
      |> get_all_posts()
      |> Enum.filter(fn post ->
        post.id != post_id and post.thread_root_id != post_id and post.parent_post_id != post_id
      end)

    {:noreply,
     assign(socket,
       posts: get_posts(socket.assigns.search_params, socket.assigns.sort, posts)
     )}
  end

  def handle_info({:post_edited, %PostSchema{} = post_edited}, socket) do
    all_posts = get_all_posts(socket.assigns.posts)

    posts =
      if post_edited.status == :submitted do
        if socket.assigns.is_instructor or post_edited.user.id == socket.assigns.user.id,
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
     )}
  end

  def handle_info(
        {:updated_collab_space_config,
         %CollabSpaceConfig{show_full_history: show_full_history} = collab_space_config},
        socket
      ) do
    search_params =
      Map.put(socket.assigns.search_params, :collab_space_config, collab_space_config)

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

  defp display_confirm_modal(modal_assigns, action, index, socket, opt_text \\ "") do
    modal = fn assigns ->
      ~F"""
      <Confirm {...@modal_assigns}>
        Are you sure you want to {action} post #{index}? {opt_text}</Confirm>
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
      {:ok, %PostSchema{} = post} ->
        socket = put_flash(socket, :info, "Post successfully edited")

        PubSub.broadcast(
          Oli.PubSub,
          socket.assigns.topic,
          {:post_edited, Repo.preload(post, :user)}
        )

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

        PubSub.broadcast(Oli.PubSub, socket.assigns.topic, {:post_deleted, post.id})

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

  defp get_posts(
         %{
           section_id: section_id,
           resource_id: page_resource_id,
           collab_space_config: collab_space_config,
           is_instructor: true
         },
         %{by: sort_by, order: sort_order}
       ) do
    Collaboration.list_posts_for_instructor_in_page_section(section_id, page_resource_id)
    |> maybe_threading(collab_space_config)
    |> sort(sort_by, sort_order)
    |> Enum.with_index(1)
  end

  defp get_posts(
         %{
           section_id: section_id,
           resource_id: page_resource_id,
           user_id: user_id,
           collab_space_config:
             %CollabSpaceConfig{show_full_history: false} = collab_space_config,
           enter_time: enter_time
         },
         %{by: sort_by, order: sort_order}
       ) do
    Collaboration.list_posts_for_user_in_page_section(
      section_id,
      page_resource_id,
      user_id,
      enter_time
    )
    |> maybe_threading(collab_space_config)
    |> sort(sort_by, sort_order)
    |> Enum.with_index(1)
  end

  defp get_posts(
         %{
           section_id: section_id,
           resource_id: page_resource_id,
           user_id: user_id,
           collab_space_config: collab_space_config
         },
         %{by: sort_by, order: sort_order}
       ) do
    Collaboration.list_posts_for_user_in_page_section(section_id, page_resource_id, user_id)
    |> maybe_threading(collab_space_config)
    |> sort(sort_by, sort_order)
    |> Enum.with_index(1)
  end

  defp get_posts(
         %{collab_space_config: collab_space_config},
         %{by: sort_by, order: sort_order},
         posts
       ) do
    posts
    |> maybe_threading(collab_space_config)
    |> sort(sort_by, sort_order)
    |> Enum.with_index(1)
  end

  defp maybe_threading(all_posts, %CollabSpaceConfig{threaded: true}) do
    Enum.reduce(all_posts, [], fn post, acc ->
      if is_nil(post.thread_root_id) do
        replies =
          all_posts
          |> Enum.filter(fn child -> child.thread_root_id == post.id end)
          |> Enum.with_index(1)

        post =
          post
          |> Map.put(:replies, replies)
          |> Map.put(:replies_count, length(replies))

        acc ++ [post]
      else
        acc
      end
    end)
  end

  defp maybe_threading(all_posts, _), do: all_posts

  defp is_archived?(:archived), do: true
  defp is_archived?(_), do: false

  defp sort(posts, :inserted_at = sort_by, sort_order) do
    Enum.sort_by(posts, &(Map.get(&1, sort_by) |> DateTime.to_unix()), sort_order)
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
end
