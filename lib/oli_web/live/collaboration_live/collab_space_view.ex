defmodule OliWeb.CollaborationLive.CollabSpaceView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.Modal

  alias Oli.Accounts
  alias Oli.Delivery.Sections
  alias Oli.Resources
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias Oli.Resources.Collaboration.Post, as: PostSchema

  alias OliWeb.CollaborationLive.{
    ShowPost,
    PostModal,
    ActiveUsers
  }

  alias OliWeb.Presence
  alias Phoenix.PubSub

  data selected, :string, default: ""
  data modal, :any, default: nil
  data editing_post, :any, default: nil
  data topic, :string
  data active_users, :list
  data posts, :list
  data post_changeset, :changeset
  data collab_space_config, :any
  data user, :any
  data section, :any
  data page_resource, :any
  data search_params, :any

  def mount(
        _,
        %{
          "collab_space_config" => collab_space_config,
          "section_slug" => section_slug,
          "page_slug" => page_slug,
          "current_user_id" => current_user_id
        } = _session,
        socket
      ) do
    topic = "cs_#{section_slug}_#{page_slug}"

    user = Accounts.get_user_by(%{id: current_user_id})
    section = Sections.get_section_by_slug(section_slug)
    page_resource = Resources.get_resource_from_slug(page_slug)

    PubSub.subscribe(Oli.PubSub, topic)
    Presence.track_presence(
      self(),
      topic,
      current_user_id,
      default_user_presence_payload(user)
    )

    post_changeset = Collaboration.change_post(%PostSchema{
      user_id: user.id,
      section_id: section.id,
      resource_id: page_resource.id
    })

    # refactor to retrieve correct status
    search_params = {
      %{section_id: section.id, resource_id: page_resource.id},
      collab_space_config
    }
    posts = get_posts(search_params)

    {:ok,
      assign(socket,
        topic: topic,
        search_params: search_params,
        page_resource: page_resource,
        section: section,
        user: user,
        active_users: Presence.list_presences(topic),
        posts: posts,
        collab_space_config: collab_space_config,
        post_changeset: post_changeset
      )}
  end

  def render(assigns) do
    ~F"""
      {#if show_collab_space?(@collab_space_config)}
        {render_modal(assigns)}

        <div class={"card" <> if @collab_space_config.status == :archived, do: " readonly", else: ""}>
          <div class="card-body">
            <div class="card-title h5">Collaborative Space</div>
          </div>
          <div class="card-footer bg-transparent d-flex justify-content-between">
            <div>
              <div class="accordion" id="post-accordion">
                <button type="button" :on-click="display_create_modal" class="btn btn-primary">+ Create</button>

                {#for {post, index} <- @posts}
                  <ShowPost
                    post={post}
                    index={index}
                    selected={@selected}
                    user={@user}
                    is_threaded={@collab_space_config.threaded}/>
                {/for}
              </div>
            </div>

            <ActiveUsers users={@active_users} />
          </div>
        </div>
      {/if}
    """
  end

  def handle_event("display_create_modal", _params, socket) do
    modal_assigns = %{
      id: "create_post_modal",
      on_submit: "create_post",
      on_change: "typing",
      on_blur: "stop_typing",
      changeset: socket.assigns.post_changeset,
      title: "Create post"
    }

    modal = fn assigns ->
      ~F"""
        <PostModal {...@modal_assigns} />
      """
    end

    {:noreply,
      socket
      |> show_modal(
        modal,
        modal_assigns: modal_assigns
      )}
  end

  def handle_event("create_post", %{"post" => attrs} = _params, socket) do
    socket = clear_flash(socket)

    case Collaboration.create_post(
           get_attrs_to_create_post(attrs, socket.assigns.collab_space_config.auto_accept)
         ) do
      {:ok, _post} ->
        socket = put_flash(socket, :info, "Post successfully created")

        PubSub.broadcast(
          Oli.PubSub,
          socket.assigns.topic,
          {:updated_post, get_posts(socket.assigns.search_params)}
        )

        {:noreply, hide_modal(socket, modal_assigns: nil)}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply, put_flash(socket, :error, "Couldn't insert post")}
    end
  end

  def handle_event("display_reply_to_post_modal", %{"parent_id" => parent_id}, socket) do
    changeset_post_reply =
      Ecto.Changeset.put_change(socket.assigns.post_changeset, :parent_post_id, parent_id)
      |> Ecto.Changeset.put_change(:thread_root_id, parent_id)

    modal_assigns = %{
      id: "create_reply_modal",
      on_submit: "create_post",
      on_change: "typing",
      on_blur: "stop_typing",
      changeset: changeset_post_reply,
      title: "Create reply"
    }

    modal = fn assigns ->
      ~F"""
        <PostModal {...@modal_assigns} />
      """
    end

    {:noreply,
     socket
     |> show_modal(
       modal,
       modal_assigns: modal_assigns
     )}
  end

  def handle_event(
        "display_reply_to_reply_modal",
        %{"parent_id" => parent_id, "root_id" => root_id},
        socket
      ) do
    changeset_post_reply =
      Ecto.Changeset.put_change(socket.assigns.post_changeset, :parent_post_id, parent_id)
      |> Ecto.Changeset.put_change(:thread_root_id, root_id)

    modal_assigns = %{
      id: "create_reply_modal",
      on_submit: "create_post",
      on_change: "typing",
      on_blur: "stop_typing",
      changeset: changeset_post_reply,
      title: "Create reply"
    }

    modal = fn assigns ->
      ~F"""
        <PostModal {...@modal_assigns} />
      """
    end

    {:noreply,
     socket
     |> show_modal(
       modal,
       modal_assigns: modal_assigns
     )}
  end

  def handle_event("display_edit_modal", %{"id" => id}, socket) do
    post = Collaboration.get_post_by(%{id: id})
    changeset = Collaboration.change_post(post)

    modal_assigns = %{
      id: "edit_post_modal",
      on_submit: "edit_post",
      on_change: "typing",
      on_blur: "stop_typing",
      changeset: changeset
    }

    modal = fn assigns ->
      ~F"""
        <PostModal {...@modal_assigns} />
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

  def handle_event(
        "edit_post",
        %{"post" => attrs},
        socket
      ) do
    socket = clear_flash(socket)

    case Collaboration.update_post(socket.assigns.editing_post, attrs) do
      {:ok, _} ->
        socket = put_flash(socket, :info, "Post successfully edited")

        PubSub.broadcast(
          Oli.PubSub,
          socket.assigns.topic,
          {:updated_post, get_posts(socket.assigns.search_params)}
        )

        {:noreply,
          socket
          |> assign(editing_post: nil)
          |> hide_modal(modal_assigns: nil)}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply, put_flash(socket, :error, "Couldn't edit post")}
    end
  end

  def handle_event("typing", _value, socket = %{assigns: %{user: _user}}) do
    # Presence.update_presence(self(), topic, user.id, %{typing: true})
    {:noreply, socket}
  end

  def handle_event(
        "stop_typing",
        %{"value" => _value},
        socket = %{assigns: %{user: _user}}
      ) do
    # Presence.update_presence(self(), topic, user.id, %{typing: false})
    {:noreply, socket}
  end

  def handle_event("set_selected", %{"id" => value}, socket) do
    {:noreply, assign(socket, selected: value)}
  end

  def handle_info({:updated_post, updated_posts}, socket) do
    {:noreply, assign(socket, posts: updated_posts)}
  end

  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply,
      assign(socket,
        users: Presence.list_presences(socket.assigns.topic)
      )}
  end

  defp default_user_presence_payload(user) do
    %{
      typing: false,
      first_name: user.name,
      email: user.email,
      user_id: user.id
    }
  end

  defp get_posts({_filter, %CollabSpaceConfig{show_full_history: false}}), do: []

  defp get_posts({filter, %CollabSpaceConfig{threaded: true}}) do
    all_posts = Collaboration.search_posts(filter)

    all_posts
    |> Enum.reduce([], fn post, acc ->
      if is_nil(post.thread_root_id) do
        replies =
          all_posts
          |> Enum.filter(fn child -> child.thread_root_id == post.id end)
          |> Enum.with_index(1)
        [Map.put(post, :replies, replies)] ++ acc
      else
        acc
      end
    end)
    |> Enum.with_index(1)
  end

  defp get_posts({filter, _}), do: Collaboration.search_posts(filter) |> Enum.with_index(1)

  defp show_collab_space?(nil), do: false
  defp show_collab_space?(%CollabSpaceConfig{status: :disabled}), do: false
  defp show_collab_space?(_), do: true

  defp get_attrs_to_create_post(attrs, true), do: attrs
  defp get_attrs_to_create_post(attrs, false), do: Map.put(attrs, "status", :submitted)
end
