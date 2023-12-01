defmodule OliWeb.Delivery.Student.DiscussionsLive do
  use OliWeb, :live_view

  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.Post
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Components.Modal
  alias OliWeb.Components.Delivery.Buttons
  alias Oli.Delivery.Sections

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

    ordered_containers_map =
      Sections.fetch_ordered_containers(socket.assigns.section.slug)
      |> Enum.into(%{})

    resource_to_container_map = Sections.get_resource_to_container_map(socket.assigns.section)

    {posts, more_posts_exist?} =
      get_posts(
        socket.assigns.current_user.id,
        socket.assigns.section.id,
        @default_post_params,
        ordered_containers_map,
        resource_to_container_map
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
        ordered_containers_map: ordered_containers_map,
        resource_to_container_map: resource_to_container_map,
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
        updated_post_params,
        socket.assigns.ordered_containers_map,
        socket.assigns.resource_to_container_map
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
        updated_post_params,
        socket.assigns.ordered_containers_map,
        socket.assigns.resource_to_container_map
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
    case Collaboration.create_post(attrs) do
      {:ok, %Post{} = post} ->
        new_post = %{
          id: post.id,
          content: post.content,
          user_name: socket.assigns.current_user.name,
          user_id: socket.assigns.current_user.id,
          posted_anonymously: post.anonymous,
          title: nil,
          slug: nil,
          resource_type_id: 2,
          updated_at: post.updated_at,
          replies_count: 0,
          last_reply: nil,
          read_replies_count: 0,
          thread_root_id: post.thread_root_id,
          is_read: true
        }

        # collab space may be configured to need approval from instructor
        if post.status == :approved,
          do:
            Phoenix.PubSub.broadcast_from(
              Oli.PubSub,
              self(),
              "collab_space_discussion_#{socket.assigns.section.slug}",
              {:discussion_created, %{new_post | is_read: false}}
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
    # case when a post reply is shown because a new_post broadcast is recieved
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
        updated_post_params,
        socket.assigns.ordered_containers_map,
        socket.assigns.resource_to_container_map
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

  # TODO add real bg-image for header and svg icons for:
  # * filter and sort
  # * message-reply
  # * plus in new discussion button
  # * right arrow in "go to page" button in page post

  def render(assigns) do
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
    <div
      id="discussions_header"
      class="relative flex items-center h-[184px] w-full bg-gray-100 dark:bg-[#0B0C11]"
    >
      <div class="absolute w-full h-full top-0 left-0 bg-[linear-gradient(90deg,#D9D9D9_0%,rgba(217,217,217,0.00)_100%)]" />
      <h1 class="pl-[100px] text-[64px] tracking-[0.02px] leading-[87px] dark:text-white z-10">
        Discussions
      </h1>
    </div>
    <div id="disussions_content" class="flex flex-col p-6 gap-6 items-start">
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
    <section id="posts" class="flex flex-col items-start px-40 w-full gap-6">
      <div role="posts header" class="flex justify-between items-center w-full self-stretch">
        <h3 class="text-2xl tracking-[0.02px] font-semibold dark:text-white">
          Posts
        </h3>
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
      </div>

      <div
        role="posts list"
        class="rounded-xl w-full bg-white shadow-md dark:bg-[rgba(255,255,255,0.06)] divide-y-[1px] divide-gray-200 dark:divide-white/20"
      >
        <%= for post <- @posts do %>
          <div
            :if={post.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("container")}
            class="p-6"
          >
            <.course_post
              post={post}
              ctx={@ctx}
              is_expanded={post.id in Map.keys(@expanded_posts)}
              is_reply={false}
              replies={Map.get(@expanded_posts, post.id, [])}
              expanded_posts={@expanded_posts}
              current_user_id={@current_user_id}
              course_collab_space_config={@course_collab_space_config}
            />
          </div>
          <.page_post
            :if={post.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("page")}
            post={post}
            ctx={@ctx}
            section_slug={@section_slug}
            current_user_id={@current_user_id}
          />
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

  _docp = """
  A course post belongs to the curriculum level.
  """

  attr :post, :map
  attr :ctx, :map
  attr :is_expanded, :boolean, default: false
  attr :replies, :list
  attr :is_reply, :boolean
  attr :expanded_posts, :map
  attr :current_user_id, :integer
  attr :course_collab_space_config, Oli.Resources.Collaboration.CollabSpaceConfig

  defp course_post(assigns) do
    ~H"""
    <div
      :if={@post[:is_first_unread]}
      id={"unread-division-post-#{@post.id}"}
      role="unread division"
      class="flex items-center gp-[10px] mb-4"
    >
      <span class="h-[1px] bg-[#FF4B47] w-full" />
      <span class="text-[12px] tracking-[1.2px] text-[#FF4B47] whitespace-nowrap">
        UNREAD REPLIES
      </span>
      <span class="h-[1px] bg-[#FF4B47] w-full" />
    </div>

    <div
      role="course post"
      id={"post-#{@post.id}"}
      class={[
        "flex flex-col gap-6",
        if(@is_reply, do: "border-l-8 border-gray-100 dark:border-gray-900/60 pl-3 pt-2")
      ]}
    >
      <div role="post header" class="flex items-center gap-2">
        <.avatar post={@post} ctx={@ctx} current_user_id={@current_user_id} />
      </div>
      <div role="post content" class="w-full">
        <p class={[
          "text-[18px] leading-[25px] dark:text-white",
          if(!@is_expanded, do: "truncate")
        ]}>
          <%= @post.content.message %>
        </p>
      </div>
      <div :if={!@is_expanded} role="post footer" class="flex justify-between items-center">
        <div role="reply details" class="flex gap-6 items-center">
          <div class="ml-[10px] flex items-center">
            <div class="relative h-8 w-8 flex items-center">
              <i class="fa-solid fa-message h-4 w-4" style="transform: scaleX(-1);" />
              <span
                :if={@post.replies_count - @post.read_replies_count > 0}
                role="unread count"
                class="absolute -top-0.5 right-2 w-4 h-4 shrink-0 rounded-full bg-[#FF4B47] text-white text-[9px] font-bold flex items-center justify-center"
              >
                <%= @post.replies_count - @post.read_replies_count %>
              </span>
            </div>
            <span
              role="replies count"
              class="text-[14px] leading-[22px] tracking-[0.02px] dark:text-white"
            >
              <%= @post.replies_count %> <%= if @post.replies_count == 1, do: "reply", else: "replies" %>
            </span>
          </div>
          <div
            :if={@post.replies_count > 0}
            role="last reply date"
            class="flex items-center gap-[6px]"
          >
            <span class="text-[14px] font-semibold leading-[22px] tracking-[0.02px] dark:text-white">
              Last Reply:
            </span>
            <span class="text-[14px] leading-[19px] tracking-[0.02px] dark:text-white/50">
              <%= FormatDateTime.parse_datetime(
                @post.last_reply,
                @ctx,
                "{WDshort}, {Mshort} {D}, {YYYY}"
              ) %>
            </span>
          </div>
        </div>
        <button
          :if={!@is_expanded}
          phx-click="expand_post"
          phx-value-post_id={@post.id}
          class="text-[14px] leading-[20px] text-[#468AEF] hover:text-[#468AEF]/70"
        >
          Open
        </button>
      </div>
      <div :if={@is_expanded} role="post replies" class="flex flex-col">
        <%= for reply <- @replies do %>
          <div class="pl-6 pb-6">
            <.course_post
              post={reply}
              ctx={@ctx}
              is_expanded={reply.id in Map.keys(@expanded_posts)}
              is_reply={true}
              replies={Map.get(@expanded_posts, reply.id, [])}
              expanded_posts={@expanded_posts}
              current_user_id={@current_user_id}
              course_collab_space_config={@course_collab_space_config}
            />
          </div>
        <% end %>
        <form
          for={%{}}
          phx-submit="post_reply"
          id={"post_reply_form_#{@post.id}"}
          class="flex items-center w-full gap-2 whitespace-nowrap"
        >
          <input
            name="content[message]"
            type="text"
            class="w-full h-9 rounded-lg"
            placeholder="Write a response..."
          />
          <input type="hidden" name={:parent_post_id} value={@post.id} />
          <input type="hidden" name={:thread_root_id} value={@post.thread_root_id || @post.id} />
          <%= if @course_collab_space_config.anonymous_posting do %>
            <div class="hidden">
              <.input
                name={:anonymous}
                type="checkbox"
                value={false}
                id={"reply_anonymous_checkbox_#{@post.id}"}
              />
            </div>
            <Buttons.button_with_options
              id={"create_post_button_#{@post.id}"}
              type="submit"
              options={[
                %{
                  text: "Post anonymously",
                  on_click:
                    JS.dispatch("click", to: "#reply_anonymous_checkbox_#{@post.id}")
                    |> JS.dispatch("click", to: "#create_post_button_#{@post.id}_button")
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
        </form>
        <button
          :if={@is_expanded}
          phx-click="collapse_post"
          phx-value-post_id={@post.id}
          class="mt-6 ml-auto text-[14px] leading-[20px] text-[#468AEF] hover:text-[#468AEF]/70"
        >
          Close Discussion
        </button>
      </div>
    </div>
    """
  end

  _docp = """
  A page post belongs to a page, so it renders additional information,
  as the page title and the container it belongs to.
  """

  attr :post, :map
  attr :ctx, :map
  attr :section_slug, :string
  attr :current_user_id, :integer

  defp page_post(assigns) do
    ~H"""
    <div role="page post" id={"post-#{@post.id}"} class="flex flex-col gap-6 p-6">
      <div role="post header" class="flex items-center gap-2">
        <.avatar post={@post} ctx={@ctx} current_user_id={@current_user_id} />
      </div>
      <div
        role="page details"
        class="flex flex-col gap-[6px] px-4 py-3 rounded-lg bg-blue-100/20 dark:bg-black/40"
      >
        <div role="post location" class="flex items-center gap-1">
          <span
            role="numbering"
            class="text-[12px] leading-[16px] tracking-[1.2px] font-bold uppercase dark:text-white"
          >
            <%= @post.page_title_with_numbering %>
          </span>
          <span role="page title" class="text-[14px] leading-[19px] dark:text-white/50">
            — <%= @post.title %>
          </span>
        </div>
        <span class="hidden text-[14px] leading-[19px] truncate dark:text-white">
          <%!-- this will render the text the user highlighted for the post --%>
        </span>
      </div>
      <div role="post content" class="w-full">
        <p class="truncate text-[18px] leading-[25px] dark:text-white">
          <%= @post.content.message %>
        </p>
      </div>
      <div role="post footer" class="flex justify-between items-center">
        <div role="reply details" class="flex gap-6 items-center">
          <div class="ml-[10px] flex items-center">
            <div class="relative h-8 w-8 flex items-center">
              <i class="fa-solid fa-message h-4 w-4" style="transform: scaleX(-1);" />
              <span
                :if={@post.replies_count - @post.read_replies_count > 0}
                role="unread count"
                class="absolute -top-0.5 right-2 w-4 h-4 shrink-0 rounded-full bg-[#FF4B47] text-white text-[9px] font-bold flex items-center justify-center"
              >
                <%= @post.replies_count - @post.read_replies_count %>
              </span>
            </div>
            <span
              role="replies count"
              class="text-[14px] leading-[22px] tracking-[0.02px] dark:text-white"
            >
              <%= @post.replies_count %> <%= if @post.replies_count == 1, do: "reply", else: "replies" %>
            </span>
          </div>
          <div
            :if={@post.replies_count > 0}
            role="last reply date"
            class="flex items-center gap-[6px]"
          >
            <span class="text-[14px] font-semibold leading-[22px] tracking-[0.02px] dark:text-white">
              Last Reply:
            </span>
            <span class="text-[14px] leading-[19px] tracking-[0.02px] dark:text-white/50">
              <%= FormatDateTime.parse_datetime(
                @post.last_reply,
                @ctx,
                "{WDshort}, {Mshort} {D}, {YYYY}"
              ) %>
            </span>
          </div>
        </div>
        <.link
          id={"page_link_#{@post.id}"}
          navigate={~p"/sections/#{@section_slug}/page/#{@post.slug}"}
          class="flex items-center gap-1 text-[14px] leading-[20px] text-[#468AEF] hover:text-[#468AEF]/70"
        >
          <span>Go to page</span>
          <svg
            role="right arrow"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="1.5"
            stroke="currentColor"
            class="w-6 h-6"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
            />
          </svg>
        </.link>
      </div>
    </div>
    """
  end

  attr :post, :map
  attr :ctx, :map
  attr :current_user_id, :integer

  # Define a list of avatar color options.
  @colors [
    "bg-[#FAE52D]",
    "bg-[#C33131]",
    "bg-[#D024A0]",
    "bg-[#FFC107]",
    "bg-[#DF8028]",
    "bg-[#168F8B]",
    "bg-[#7940F3]",
    "bg-[#2080F0]"
  ]

  def avatar(assigns) do
    ~H"""
    <div class={[
      "w-8 h-8 rounded-full flex items-center justify-center shrink-0",
      get_color_for_name(@post.user_name)
    ]}>
      <span role="avatar initials" class="text-[14px] text-white uppercase">
        <%= to_initials(@post, @current_user_id) %>
      </span>
    </div>
    <div class="flex flex-col items-start gap-[1px]">
      <span
        role="user name"
        class="text-[16px] leading-[22px] tracking-[0.02px] font-semibold dark:text-white"
      >
        <%= user_name(@post, @current_user_id) %>
      </span>
      <span role="posted at" class="text-[14px] leading-[19px] tracking-[0.02px] dark:text-white/50">
        <%= FormatDateTime.parse_datetime(
          @post.updated_at,
          @ctx,
          "{WDshort}, {Mshort} {D}, {YYYY}"
        ) %>
      </span>
    </div>
    """
  end

  defp user_name(%{posted_anonymously: false, user_name: user_name} = _post, _current_user_id),
    do: user_name

  defp user_name(
         %{posted_anonymously: true, user_name: user_name, user_id: user_id} = _post,
         current_user_id
       )
       when user_id == current_user_id,
       do: "#{user_name} (anonymously)"

  defp user_name(%{posted_anonymously: true, user_id: user_id} = _post, current_user_id)
       when user_id != current_user_id,
       do: "Anonymous User"

  # Generate a consistent color based on the user's name.
  defp get_color_for_name(user_name) do
    # Create a hash of the user name.
    hash = :erlang.phash2(user_name)

    # Use the hash to select a color.
    Enum.at(@colors, rem(hash, length(@colors)))
  end

  defp to_initials(%{posted_anonymously: true, user_id: user_id}, current_user_id)
       when current_user_id != user_id,
       do: "?"

  defp to_initials(%{user_name: user_name}, _current_user_id) do
    user_name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.slice(&1, 0..0))
    |> Enum.join()
  end

  defp get_posts(
         current_user_id,
         section_id,
         post_params,
         ordered_containers_map,
         resource_to_container_map
       ) do
    {posts_without_page_title, more_posts_exist?} =
      Collaboration.list_root_posts_for_section(
        current_user_id,
        section_id,
        post_params.limit,
        post_params.offset,
        post_params.filter_by,
        post_params.sort_by,
        post_params.sort_order
      )

    posts_with_page_title =
      add_page_title_with_numbering_to_page_posts(
        posts_without_page_title,
        ordered_containers_map,
        resource_to_container_map
      )

    {posts_with_page_title, more_posts_exist?}
  end

  defp add_page_title_with_numbering_to_page_posts([], _ordered_containers_map, _section), do: []

  defp add_page_title_with_numbering_to_page_posts(
         posts,
         ordered_containers_map,
         resource_to_container_map
       ) do
    Enum.map(posts, fn post ->
      if post.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("page") do
        page_title_with_numbering =
          case Map.get(resource_to_container_map, Integer.to_string(post.resource_id)) do
            nil ->
              "Page #{post.resource_numbering_index}"

            container_resource_id ->
              container_with_numbering_index =
                Map.get(ordered_containers_map, container_resource_id)
                |> String.split(":")
                |> hd()

              "#{container_with_numbering_index}: Page #{post.resource_numbering_index}"
          end

        post
        |> Map.put(
          :page_title_with_numbering,
          page_title_with_numbering
        )
      else
        post
      end
    end)
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
