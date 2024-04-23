defmodule OliWeb.Delivery.Student.DiscussionsLive do
  use OliWeb, :live_view

  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.Post
  alias Oli.Delivery.Sections
  alias OliWeb.Components.Modal
  alias OliWeb.Components.Delivery.Buttons
  alias OliWeb.Delivery.Student.Lesson.Annotations

  @default_post_params %{
    sort_by: "date",
    sort_order: :desc,
    filter_by: "all",
    offset: 0,
    limit: 5
  }

  def mount(_params, _session, socket) do
    if connected?(socket),
      do:
        Phoenix.PubSub.subscribe(
          Oli.PubSub,
          "collab_space_discussion_#{socket.assigns.section.slug}"
        )

    {posts, more_posts_exist?} =
      get_posts(
        socket.assigns.current_user.id,
        socket.assigns.section.id,
        @default_post_params
      )

    {
      :ok,
      assign(socket,
        active_tab: :discussions,
        posts: posts,
        expanded_posts: %{},
        course_collab_space_config:
          Collaboration.get_course_collab_space_config(
            socket.assigns.section.root_section_resource_id
          ),
        post_params: @default_post_params,
        more_posts_exist?: more_posts_exist?,
        root_section_resource_resource_id:
          Sections.get_root_section_resource_resource_id(socket.assigns.section)
      )
      |> assign_new_discussion_form()
    }
  end

  def handle_event("filter_posts", %{"filter_by" => filter_by}, socket)
      when filter_by == socket.assigns.post_params.filter_by do
    # do not change the UI if the user selects the same filter as before
    {:noreply, socket}
  end

  def handle_event("filter_posts", %{"filter_by" => filter_by}, socket) do
    updated_post_params =
      Map.merge(socket.assigns.post_params, %{filter_by: filter_by, offset: 0})

    {posts, more_posts_exist?} =
      get_posts(
        socket.assigns.current_user.id,
        socket.assigns.section.id,
        updated_post_params
      )

    {:noreply,
     assign(
       socket,
       posts: posts,
       more_posts_exist?: more_posts_exist?,
       post_params: updated_post_params,
       expanded_posts: %{}
     )}
  end

  def handle_event("sort_posts", %{"sort_by" => sort_by}, socket) do
    updated_post_params =
      Map.merge(socket.assigns.post_params, %{
        sort_by: sort_by,
        sort_order:
          get_sort_order(
            socket.assigns.post_params.sort_by,
            sort_by,
            socket.assigns.post_params.sort_order
          )
      })

    {posts, more_posts_exist?} =
      get_posts(
        socket.assigns.current_user.id,
        socket.assigns.section.id,
        updated_post_params
      )

    {:noreply,
     assign(
       socket,
       posts: posts,
       post_params: updated_post_params,
       more_posts_exist?: more_posts_exist?
     )}
  end

  def handle_event("reset_discussion_modal", _, socket) do
    {:noreply, assign_new_discussion_form(socket)}
  end

  def handle_event("create_new_discussion", %{"post" => attrs} = _params, socket) do
    case Collaboration.create_post(Map.merge(attrs, %{"visibility" => :public})) do
      {:ok, %Post{} = post} ->
        new_post = %Post{
          post
          | resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
            replies_count: 0,
            read_replies_count: 0,
            is_read: true,
            reaction_summaries: %{},
            replies: nil
        }

        # collab space may be configured to need approval from instructor
        if post.status == :approved,
          do:
            Phoenix.PubSub.broadcast_from(
              Oli.PubSub,
              self(),
              "collab_space_discussion_#{socket.assigns.section.slug}",
              {:discussion_created, %Post{new_post | is_read: false}}
            )

        {:noreply, assign(socket, :posts, [new_post | socket.assigns.posts])}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Couldn't create post")}
    end
  end

  def handle_event("expand_post", %{"post_id" => post_id}, socket) do
    post_replies =
      Collaboration.list_replies_for_post(
        socket.assigns.current_user.id,
        post_id
      )
      |> group_unread_last()

    updated_expanded_posts =
      Map.merge(
        socket.assigns.expanded_posts,
        Enum.into([{String.to_integer(post_id), post_replies}], %{})
      )

    Collaboration.mark_posts_as_read(post_replies, socket.assigns.current_user.id, true)

    {:noreply, assign(socket, expanded_posts: updated_expanded_posts)}
  end

  def handle_event("collapse_post", %{"post_id" => post_id}, socket) do
    # mark the collapsed posts replies as read
    # although we mark them when expanded, we need to handle the
    # case when a post reply is shown because a new_post broadcast is received
    # while having the parent post expanded.
    Collaboration.mark_posts_as_read(
      Map.get(socket.assigns.expanded_posts, String.to_integer(post_id), []),
      socket.assigns.current_user.id
    )

    # update the metrics of the parent post that just was collapsed
    # and remove it from the expanded posts map.
    collapsed_post = Collaboration.get_post_by(id: post_id)

    {updated_root_posts, updated_expanded_posts} =
      update_metrics_of_thread(
        socket.assigns.posts,
        Map.drop(socket.assigns.expanded_posts, [String.to_integer(post_id)]),
        collapsed_post,
        socket.assigns.current_user.id
      )

    {:noreply,
     socket
     |> assign(posts: updated_root_posts)
     |> assign(expanded_posts: updated_expanded_posts)}
  end

  def handle_event(
        "post_reply",
        %{"content" => %{"message" => ""}},
        socket
      ) do
    {:noreply, socket}
  end

  def handle_event(
        "post_reply",
        attrs,
        socket
      ) do
    attrs =
      Map.merge(attrs, %{
        "user_id" => socket.assigns.current_user.id,
        "section_id" => socket.assigns.section.id,
        "resource_id" => socket.assigns.root_section_resource_resource_id,
        "status" =>
          if(socket.assigns.course_collab_space_config.auto_accept,
            do: :approved,
            else: :submitted
          )
      })

    case Collaboration.create_post(attrs) do
      {:ok, %Post{} = new_post} ->
        {updated_root_posts, updated_expanded_posts} =
          update_metrics_of_thread(
            socket.assigns.posts,
            socket.assigns.expanded_posts,
            new_post,
            socket.assigns.current_user.id
          )

        # collab space may be configured to need approval from instructor
        if new_post.status == :approved,
          do:
            Phoenix.PubSub.broadcast_from(
              Oli.PubSub,
              self(),
              "collab_space_discussion_#{socket.assigns.section.slug}",
              {:reply_posted, new_post}
            )

        {:noreply,
         assign(socket, expanded_posts: updated_expanded_posts, posts: updated_root_posts)}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Couldn't create post")}
    end
  end

  def handle_event("load_more_posts", _, socket) do
    updated_post_params =
      Map.merge(socket.assigns.post_params, %{
        offset: socket.assigns.post_params.offset + socket.assigns.post_params.limit
      })

    {posts, more_posts_exist?} =
      get_posts(
        socket.assigns.current_user.id,
        socket.assigns.section.id,
        updated_post_params
      )

    case posts do
      [] ->
        {:noreply, assign(socket, more_posts_exist?: false)}

      more_posts ->
        {:noreply,
         assign(socket,
           posts: socket.assigns.posts ++ more_posts,
           post_params: updated_post_params,
           more_posts_exist?: more_posts_exist?
         )}
    end
  end

  def handle_info({:discussion_created, _new_post}, socket)
      when socket.assigns.post_params.filter_by in ["my_activity", "page_discussions"] do
    # new broadcasted post should not be added to the UI if the user is filtering by "my activity"
    # since the new post belongs to another user and the current user has not yet interacted/replied to it.
    # The same applies to "page_discussions" since the new broadcasted posts belong to course discussions.
    {:noreply, socket}
  end

  def handle_info({:discussion_created, new_post}, socket) do
    {:noreply, assign(socket, :posts, [new_post | socket.assigns.posts])}
  end

  def handle_info({:reply_posted, new_post}, socket) do
    {updated_root_posts, updated_expanded_posts} =
      update_metrics_of_thread(
        socket.assigns.posts,
        socket.assigns.expanded_posts,
        new_post,
        socket.assigns.current_user.id
      )

    {:noreply, assign(socket, expanded_posts: updated_expanded_posts, posts: updated_root_posts)}
  end

  def render(assigns) do
    ~H"""
    <.create_discussion_modal
      course_collab_space_config={@course_collab_space_config}
      new_discussion_form_uuid={@new_discussion_form_uuid}
      new_discussion_form={@new_discussion_form}
    />
    <.hero_banner class="bg-discussions">
      <h1 class="text-6xl mb-8">Discussions</h1>
    </.hero_banner>
    <div id="discussions_content" class="flex flex-col py-6 px-16 gap-6 items-start">
      <.posts_section
        posts={@posts}
        ctx={@ctx}
        section_slug={@section.slug}
        expanded_posts={@expanded_posts}
        current_user_id={@current_user.id}
        course_collab_space_config={@course_collab_space_config}
        new_discussion_form_uuid={@new_discussion_form_uuid}
        post_params={@post_params}
        more_posts_exist?={@more_posts_exist?}
      />
    </div>
    """
  end

  attr :course_collab_space_config, Oli.Resources.Collaboration.CollabSpaceConfig
  attr :new_discussion_form_uuid, :string
  attr :new_discussion_form, :map

  defp create_discussion_modal(assigns) do
    ~H"""
    <div phx-hook="TextareaListener" id="modal_wrapper">
      <Modal.modal
        :if={@course_collab_space_config && @course_collab_space_config.status == :enabled}
        class="w-1/2"
        on_cancel={JS.push("reset_discussion_modal")}
        id={"new-discussion-modal-#{@new_discussion_form_uuid}"}
      >
        <:title>New Discussion</:title>
        <.form
          for={@new_discussion_form}
          id="new_discussion_form"
          phx-submit={
            JS.push("create_new_discussion")
            |> Modal.hide_modal("new-discussion-modal-#{@new_discussion_form_uuid}")
            |> JS.push("reset_discussion_modal")
          }
        >
          <.input type="hidden" field={@new_discussion_form[:user_id]} />
          <.input type="hidden" field={@new_discussion_form[:section_id]} />
          <.input type="hidden" field={@new_discussion_form[:resource_id]} />
          <.input type="hidden" field={@new_discussion_form[:parent_post_id]} />
          <.input type="hidden" field={@new_discussion_form[:thread_root_id]} />
          <.input type="hidden" field={@new_discussion_form[:status]} />

          <.inputs_for :let={post_content} field={@new_discussion_form[:content]}>
            <.input
              type="textarea"
              field={post_content[:message]}
              autocomplete="off"
              placeholder="Start a discussion..."
              data-grow="true"
              data-initial-height={44}
              onkeyup="resizeTextArea(this)"
              class="torus-input border-r-0 collab-space__textarea"
            />
          </.inputs_for>

          <div class="flex items-center justify-end">
            <.button
              phx-click={
                Modal.hide_modal("new-discussion-modal-#{@new_discussion_form_uuid}")
                |> JS.push("reset_discussion_modal")
              }
              type="button"
              class="bg-transparent text-blue-500 hover:underline hover:bg-transparent"
            >
              Cancel
            </.button>
            <%= if @course_collab_space_config.anonymous_posting do %>
              <div class="hidden">
                <.input
                  type="checkbox"
                  id="new_discussion_anonymous_checkbox"
                  field={@new_discussion_form[:anonymous]}
                />
              </div>
              <Buttons.button_with_options
                id="create_post_button"
                type="submit"
                options={[
                  %{
                    text: "Post anonymously",
                    on_click:
                      JS.dispatch("click", to: "#new_discussion_anonymous_checkbox")
                      |> JS.dispatch("click", to: "#create_post_button_button")
                  }
                ]}
              >
                Create Post
              </Buttons.button_with_options>
            <% else %>
              <Buttons.button type="submit">
                Create Post
              </Buttons.button>
            <% end %>
          </div>
        </.form>
      </Modal.modal>
    </div>
    """
  end

  attr :posts, :list
  attr :ctx, :map
  attr :section_slug, :string
  attr :expanded_posts, :map
  attr :current_user_id, :integer
  attr :course_collab_space_config, Oli.Resources.Collaboration.CollabSpaceConfig
  attr :new_discussion_form_uuid, :string
  attr :post_params, :map
  attr :more_posts_exist?, :boolean

  defp posts_section(assigns) do
    ~H"""
    <section id="posts" class="container mx-auto flex flex-col items-start w-full gap-6">
      <div role="posts header" class="flex justify-between items-center w-full self-stretch">
        <h3 class="text-2xl tracking-[0.02px] font-semibold dark:text-white">
          Course Discussions
        </h3>
      </div>

      <.actions
        post_params={@post_params}
        course_collab_space_config={@course_collab_space_config}
        new_discussion_form_uuid={@new_discussion_form_uuid}
      />

      <div role="posts list" class="w-full">
        <%= for post <- @posts do %>
          <div
            :if={post.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("container")}
            class="mb-3"
          >
            <Annotations.post class="bg-white" post={post} current_user={@ctx.user} />
          </div>
        <% end %>
        <div :if={@posts == []} class="flex p-4 text-center w-full">
          There are no discussions to show.
        </div>
        <div class="flex w-full justify-end">
          <button
            :if={@more_posts_exist?}
            phx-click="load_more_posts"
            class="text-primary text-sm px-6 py-2 hover:text-primary/70"
          >
            Load more posts
          </button>
        </div>
      </div>
    </section>
    """
  end

  attr :post_params, :map
  attr :course_collab_space_config, Oli.Resources.Collaboration.CollabSpaceConfig
  attr :new_discussion_form_uuid, :string

  defp actions(assigns) do
    ~H"""
    <div role="posts actions" class="flex items-center justify-end gap-6">
      <div class="flex space-x-3">
        <.dropdown
          id="filter-dropdown"
          role="filter"
          button_class="flex items-center gap-[10px] px-[10px] py-[4px] hover:text-gray-400 dark:text-white dark:hover:text-white/50"
          options={
            [
              %{
                text: "All",
                on_click: JS.push("filter_posts", value: %{filter_by: "all"}),
                class:
                  if(@post_params.filter_by == "all",
                    do: "font-bold dark:font-extrabold",
                    else: "dark:font-light"
                  )
              }
            ] ++
              if(@course_collab_space_config && @course_collab_space_config.status == :enabled,
                do: [
                  %{
                    text: "Course Discussions",
                    on_click: JS.push("filter_posts", value: %{filter_by: "course_discussions"}),
                    class:
                      if(@post_params.filter_by == "course_discussions",
                        do: "font-bold dark:font-extrabold",
                        else: "dark:font-light"
                      )
                  },
                  %{
                    text: "Page Discussions",
                    on_click: JS.push("filter_posts", value: %{filter_by: "page_discussions"}),
                    class:
                      if(@post_params.filter_by == "page_discussions",
                        do: "font-bold dark:font-extrabold",
                        else: "dark:font-light"
                      )
                  }
                ],
                else: []
              ) ++
              [
                %{
                  text: "Unread",
                  on_click: JS.push("filter_posts", value: %{filter_by: "unread"}),
                  class:
                    if(@post_params.filter_by == "unread",
                      do: "font-bold dark:font-extrabold",
                      else: "dark:font-light"
                    )
                },
                %{
                  text: "My Activity",
                  on_click: JS.push("filter_posts", value: %{filter_by: "my_activity"}),
                  class:
                    if(@post_params.filter_by == "my_activity",
                      do: "font-bold dark:font-extrabold",
                      else: "dark:font-light"
                    )
                }
              ]
          }
        >
          <span class="text-[14px] leading-[20px]">Filter</span>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <line x1="3" y1="6" x2="21" y2="6"></line>
            <line x1="6" y1="12" x2="18" y2="12"></line>
            <line x1="9" y1="18" x2="15" y2="18"></line>
          </svg>
        </.dropdown>

        <.dropdown
          id="sort-dropdown"
          role="sort"
          button_class="flex items-center gap-[10px] px-[10px] py-[4px] hover:text-gray-400 dark:text-white dark:hover:text-white/50"
          options={[
            %{
              text: "Date",
              on_click: JS.push("sort_posts", value: %{sort_by: "date"}),
              icon: sort_by_icon(@post_params.sort_by == "date", @post_params.sort_order),
              class:
                if(@post_params.sort_by == "date",
                  do: "font-bold dark:font-extrabold",
                  else: "dark:font-light"
                )
            },
            %{
              text: "Popularity",
              on_click: JS.push("sort_posts", value: %{sort_by: "popularity"}),
              icon: sort_by_icon(@post_params.sort_by == "popularity", @post_params.sort_order),
              class:
                if(@post_params.sort_by == "popularity",
                  do: "font-bold dark:font-extrabold",
                  else: "dark:font-light"
                )
            }
          ]}
        >
          <span class="text-[14px] leading-[20px]">Sort</span>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <line x1="3" y1="6" x2="21" y2="6"></line>
            <line x1="3" y1="12" x2="14" y2="12"></line>
            <line x1="3" y1="18" x2="7" y2="18"></line>
          </svg>
        </.dropdown>
      </div>

      <button
        :if={@course_collab_space_config && @course_collab_space_config.status == :enabled}
        role="new discussion"
        phx-click={Modal.show_modal("new-discussion-modal-#{@new_discussion_form_uuid}")}
        class="rounded-[3px] py-[10px] pl-[18px] pr-6 flex justify-center items-center whitespace-nowrap text-[14px] leading-[20px] font-normal text-white bg-[#0F6CF5] hover:bg-blue-600"
      >
        <svg
          role="plus icon"
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="1.5"
          stroke="currentColor"
          class="w-6 h-6 mr-[10px]"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
        </svg>
        New Discussion
      </button>
    </div>
    """
  end

  defp get_posts(
         current_user_id,
         section_id,
         post_params
       ) do
    {posts, more_posts_exist?} =
      Collaboration.list_root_posts_for_section(
        current_user_id,
        section_id,
        post_params.limit,
        post_params.offset,
        post_params.filter_by,
        post_params.sort_by,
        post_params.sort_order
      )

    {posts, more_posts_exist?}
  end

  defp assign_new_discussion_form(socket) do
    if socket.assigns.course_collab_space_config,
      do:
        assign(socket,
          new_discussion_form_uuid: UUID.uuid4(),
          new_discussion_form:
            new_discussion_form(
              socket.assigns.current_user.id,
              socket.assigns.section.id,
              socket.assigns.course_collab_space_config,
              socket.assigns.root_section_resource_resource_id
            )
        ),
      else: assign(socket, new_discussion_form_uuid: nil, new_discussion_form: nil)
  end

  defp new_discussion_form(
         current_user_id,
         section_id,
         course_collab_space_config,
         root_section_resource_resource_id
       ) do
    to_form(
      Collaboration.change_post(%Post{
        user_id: current_user_id,
        section_id: section_id,
        resource_id: root_section_resource_resource_id,
        status: if(course_collab_space_config.auto_accept, do: :approved, else: :submitted)
      })
    )
  end

  defp update_metrics_of_thread(root_posts, expanded_posts, new_post, current_user_id) do
    # we need to update the metrics of the root post the new post belongs to
    # (considering the case where the new post is a root post itself)
    updated_root_posts =
      Enum.map(root_posts, fn root_post ->
        if root_post.id == new_post.thread_root_id or root_post.id == new_post.id do
          Collaboration.rebuild_metrics_for_root_post(root_post, current_user_id)
        else
          root_post
        end
      end)

    # and update the metrics for the expanded posts that belong
    # to the same thread as the new post
    updated_expanded_posts =
      Enum.into(expanded_posts, %{}, fn
        {expanded_post_id, _expanded_replies} when expanded_post_id == new_post.parent_post_id ->
          # the new post must be shown as part of the expanded replies
          {expanded_post_id,
           Collaboration.list_replies_for_post(
             current_user_id,
             new_post.parent_post_id
           )
           |> group_unread_last()}

        {expanded_post_id, [expanded_reply | _rest] = expanded_replies}
        when expanded_reply.thread_root_id == new_post.thread_root_id ->
          {expanded_post_id,
           Collaboration.build_metrics_for_reply_posts(expanded_replies, current_user_id)
           |> group_unread_last()}

        {expanded_post_id, expanded_replies} ->
          {expanded_post_id, expanded_replies}
      end)

    {updated_root_posts, updated_expanded_posts}
  end

  defp get_sort_order(current_sort_by, new_sort_by, sort_order)
       when current_sort_by == new_sort_by,
       do: toggle_sort_order(sort_order)

  defp get_sort_order(_current_sort_by, _new_sort_by, sort_order), do: sort_order

  defp toggle_sort_order(:asc), do: :desc
  defp toggle_sort_order(:desc), do: :asc

  defp sort_by_icon(true, :desc), do: ~s{<i class="fa-solid fa-arrow-down"></i>}
  defp sort_by_icon(true, :asc), do: ~s{<i class="fa-solid fa-arrow-up"></i>}
  defp sort_by_icon(false, _), do: nil

  _docp = """
   If there are any unread posts (or posts with unread replies), they are grouped at the end of the list
   and, in case there are any read post, the first unread post is marked with a flag.
   This flag is used to render the "UNREAD REPLIES" label in the UI.
  """

  defp group_unread_last(posts) when posts in [nil, []], do: []

  defp group_unread_last(posts) do
    {read_posts, unread_posts} =
      Enum.reduce(posts, {[], []}, fn post, {read_posts, unread_posts} ->
        if post.replies_count - post.read_replies_count > 0 or
             !post.is_read do
          {read_posts, [post | unread_posts]}
        else
          {[post | read_posts], unread_posts}
        end
      end)

    Enum.reverse(read_posts) ++
      add_first_unread_flag(Enum.reverse(unread_posts))
  end

  _docp = """
  The first unread post is marked with a flag, so it can be rendered differently in the UI, showing
  a "UNREAD REPLIES" label on top.
  We also need to mark the other posts in the thread as `is_first_unread: false` to
  avoid issues when the current liveview recieves a broadcasted new post in the expanded thread.
  If not, two unread posts end up having the flag => two "UNREAD REPLIES" labels.
  """

  defp add_first_unread_flag([]), do: []

  defp add_first_unread_flag([first_unread_post | rest]),
    do: [
      Map.merge(first_unread_post, %{is_first_unread: true})
      | Enum.map(rest, fn r -> Map.merge(r, %{is_first_unread: false}) end)
    ]
end
