defmodule OliWeb.Delivery.Student.DiscussionsLive do
  use OliWeb, :live_view

  import OliWeb.Components.Delivery.Layouts

  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.Post
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Components.Modal
  alias OliWeb.Components.Delivery.Buttons

  # There are many Figma designs, I assumed I must consider the one at the top.

  # course_post
  # only consider posts attached to a container

  # always consider posts from level 0 (parent_post_id and thread_root_id are null)
  # to render a card. For course posts level 1 posts will be shown when clicking "open"
  # How do we handle cases when there are posts at level 2 or more? we can expand them again (an open button
  # should be added), and rendered indented.
  # We will be able to repond to course_posts at level 0, right? yes

  # we actually do not handle "uread posts" functionality. This must be done (leave it for the end in case design changes)

  # what is the text rendered in a page post under the module and page title?
  # it is supposed to be the text the user highlighted from the page while submitting the post.

  # do we have a way to get the module a page belongs to (MODULE 3.1 PAGE 7)? see resource_to_container_map to get the parent container.
  # Number them in the "original way".

  # NEW DISCUSSION button:
  # what is the behavior? no design, but it should render a modal to enter a new post (only for course level posts)

  # REPLY COUNT and LAST REPLY DATE:
  # Do we consider only direct replies to the post or all replies in the thread? All levels (no 100% seguro)

  # view all posts -> we do not want to fetch all posts (it might be expensive) => implement it with infinite scroll + stream (Chis McCord's talk)

  @default_post_params %{sort_by: "date", sort_order: :desc, filter_by: "all"}

  # TODO para el viernes...
  # esta mal cómo estoy haciendo el sort, debería hacerlo en la query como hago con el filter (no se cómo en el caso de popularity...)
  # pensar el tema de los broadcasts... si me llega un post de otro usuario y tengo filtrado por "my activity" no debería aparecer (salvo que sea una reply a un thread en el que sí tengo actividad)
  # pensar el tema de los broadcasts... si me llega un post de otro usuario y tengo filtrado por "unread" creo que siempre debería aparecer
  # pensar cómo voy a matchear el tema de los unread y su modelo de datos de caras a los broadcast y a que no sea un chino para las metricas
  def mount(_params, _session, socket) do
    if connected?(socket),
      do:
        Phoenix.PubSub.subscribe(
          Oli.PubSub,
          "collab_space_discussion_#{socket.assigns.section.slug}"
        )

    {
      :ok,
      assign(socket,
        posts:
          Collaboration.list_root_posts_for_section(
            socket.assigns.current_user.id,
            socket.assigns.section.id,
            nil
          ),
        expanded_posts: %{},
        course_collab_space_config:
          Collaboration.get_course_collab_space_config(
            socket.assigns.section.root_section_resource_id
          ),
        post_params: @default_post_params
      )
      |> assign_new_discussion_form()
    }
  end

  def handle_event("filter_posts", %{"filter_by" => filter_by}, socket) do
    {:noreply,
     assign(
       socket,
       posts:
         Collaboration.list_root_posts_for_section(
           socket.assigns.current_user.id,
           socket.assigns.section.id,
           nil,
           filter_by
         )
         |> sort_posts(socket.assigns.post_params.sort_by, socket.assigns.post_params.sort_order),
       post_params: Map.merge(socket.assigns.post_params, %{filter_by: filter_by})
     )}
  end

  def handle_event("sort_posts", %{"sort_by" => sort_by}, socket) do
    {:noreply,
     assign(
       socket,
       posts:
         Collaboration.list_root_posts_for_section(
           socket.assigns.current_user.id,
           socket.assigns.section.id,
           nil,
           socket.assigns.post_params.filter_by
         )
         |> sort_posts(
           sort_by,
           get_sort_order(
             socket.assigns.post_params.sort_by,
             sort_by,
             socket.assigns.post_params.sort_order
           )
         ),
       post_params:
         Map.merge(socket.assigns.post_params, %{
           sort_by: sort_by,
           sort_order:
             get_sort_order(
               socket.assigns.post_params.sort_by,
               sort_by,
               socket.assigns.post_params.sort_order
             )
         })
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

    mark_posts_as_read(post_replies, socket.assigns.current_user.id)

    {:noreply, assign(socket, expanded_posts: updated_expanded_posts)}
  end

  def handle_event("collapse_post", %{"post_id" => post_id}, socket) do
    # mark the collapsed posts replies as read
    # although we mark them when expanded, we need to handle the
    # case when a post reply is shown because a new_post broadcast is recieved
    # while having the parent post expanded.
    mark_posts_as_read(
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

    # TODO, when collapsing a post, also collapse all expanded children

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
    # TODO give feedback to user
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
        "resource_id" => 4,
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
    <.header_with_sidebar_nav
      ctx={@ctx}
      section={@section}
      brand={@brand}
      preview_mode={@preview_mode}
      active_tab={:discussions}
    >
      <div phx-hook="TextareaListener" id="modal_wrapper">
        <Modal.modal
          class="w-1/2"
          on_cancel={JS.push("reset_discussion_modal")}
          id={"new-discussion-modal-#{@new_discussion_form_uuid}"}
        >
          <:title>New Discussion</:title>
          <.form
            for={@new_discussion_form}
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
        />
      </div>
    </.header_with_sidebar_nav>
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
              options={[
                %{
                  text: "All",
                  on_click: JS.push("filter_posts", value: %{filter_by: "all"}),
                  class:
                    if(@post_params.filter_by == "all",
                      do: "font-bold dark:font-extrabold",
                      else: "dark:font-light"
                    )
                },
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
              ]}
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
            :if={@course_collab_space_config.status == :enabled}
            role="new discussion"
            phx-click={Modal.show_modal("new-discussion-modal-#{@new_discussion_form_uuid}")}
            class="rounded-[3px] py-[10px] pl-[18px] pr-6 flex justify-center items-center text-[14px] leading-[20px] font-normal text-white bg-[#0F6CF5] hover:bg-blue-600"
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
          <div :if={post.resource_type_id == 2} class="p-6">
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
            :if={post.resource_type_id != 2}
            post={post}
            ctx={@ctx}
            section_slug={@section_slug}
            current_user_id={@current_user_id}
          />
        <% end %>
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
    <div :if={@post[:is_first_unread]} class="flex items-center gap-[10px] mb-4">
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
            <span class="text-[14px] leading-[22px] tracking-[0.02px] dark:text-white">
              <%= @post.replies_count %> <%= if @post.replies_count == 1, do: "reply", else: "replies" %>
            </span>
          </div>
          <div :if={@post.replies_count > 0} class="flex items-center gap-[6px]">
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
    <div role="post-2" class="flex flex-col gap-6 p-6">
      <div role="post header" class="flex items-center gap-2">
        <.avatar post={@post} ctx={@ctx} current_user_id={@current_user_id} />
      </div>
      <div
        role="page details"
        class="flex flex-col gap-[6px] px-4 py-3 rounded-lg bg-blue-100/20 dark:bg-black/40"
      >
        <div role="post location" class="flex items-center gap-1">
          <span class="text-[12px] leading-[16px] tracking-[1.2px] font-bold uppercase dark:text-white">
            Module 3.1 Page 7
          </span>
          <span class="text-[14px] leading-[19px] dark:text-white/50">
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
            <span class="text-[14px] leading-[22px] tracking-[0.02px] dark:text-white">
              <%= @post.replies_count %> <%= if @post.replies_count == 1, do: "reply", else: "replies" %>
            </span>
          </div>
          <div :if={@post.replies_count > 0} class="flex items-center gap-[6px]">
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
      <span class="text-[14px] text-white uppercase">
        <%= to_initials(@post, @current_user_id) %>
      </span>
    </div>
    <div class="flex flex-col items-start gap-[1px]">
      <span class="text-[16px] leading-[22px] tracking-[0.02px] font-semibold dark:text-white">
        <%= user_name(@post, @current_user_id) %>
      </span>
      <span class="text-[14px] leading-[19px] tracking-[0.02px] dark:text-white/50">
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

  defp assign_new_discussion_form(socket) do
    assign(socket,
      new_discussion_form_uuid: UUID.uuid4(),
      new_discussion_form:
        new_discussion_form(
          socket.assigns.current_user.id,
          socket.assigns.section.id,
          socket.assigns.course_collab_space_config
        )
    )
  end

  defp new_discussion_form(current_user_id, section_id, course_collab_space_config) do
    to_form(
      Collaboration.change_post(%Post{
        user_id: current_user_id,
        section_id: section_id,
        resource_id: 4,
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
          Collaboration.build_metrics_for_root_posts(root_post, current_user_id)
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

  defp sort_posts(posts, sort_by, sort_order) do
    case sort_by do
      "date" ->
        Enum.sort_by(posts, & &1.updated_at, {sort_order, DateTime})

      "popularity" ->
        Enum.sort_by(posts, & &1.replies_count, sort_order)
    end
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
      add_first_unread_flag(Enum.reverse(unread_posts), length(read_posts))
  end

  _docp = """
  The first unread post is marked with a flag, so it can be rendered differently in the UI, showing
  a "UNREAD REPLIES" label on top.
  We also need to mark the other posts in the thread as `is_first_unread: false` to
  avoid issues when the current liveview recieves a broadcasted new post in the expanded thread.
  If not, two unread posts end up having the flag => two "UNREAD REPLIES" labels.
  """

  defp add_first_unread_flag([], _), do: []

  defp add_first_unread_flag(posts, 0),
    do: Enum.map(posts, fn p -> Map.merge(p, %{is_first_unread: false}) end)

  defp add_first_unread_flag([first_unread_post | rest], read_posts_count)
       when read_posts_count > 0,
       do: [
         Map.merge(first_unread_post, %{is_first_unread: true})
         | Enum.map(rest, fn r -> Map.merge(r, %{is_first_unread: false}) end)
       ]

  defp mark_posts_as_read(posts, user_id) do
    Enum.reduce(posts, [], fn post, acc ->
      if post.user_id != user_id, do: [post.id | acc], else: acc
    end)
    |> Collaboration.read_posts(user_id)
  end
end
