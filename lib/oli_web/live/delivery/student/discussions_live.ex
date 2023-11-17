defmodule OliWeb.Delivery.Student.DiscussionsLive do
  use OliWeb, :live_view

  import OliWeb.Components.Delivery.Layouts

  alias Oli.Resources.Collaboration
  alias OliWeb.Common.FormatDateTime

  def mount(
        _params,
        _session,
        socket
      ) do
    posts =
      Collaboration.list_level_0_course_and_page_posts_for_section(
        socket.assigns.current_user.id,
        socket.assigns.section.id,
        20
      )
      |> Enum.reduce(%{course_posts: [], page_posts: []}, fn post, acc ->
        if post.resource_type_id == 2 do
          %{acc | course_posts: [post | acc.course_posts]}
        else
          %{acc | page_posts: [post | acc.page_posts]}
        end
      end)

    {:ok, assign(socket, posts: posts, expanded_posts: %{})}
  end

  def handle_event("expand_post", %{"post_id" => post_id}, socket) do
    post_replies =
      Collaboration.list_replies_for_post(
        socket.assigns.current_user.id,
        post_id
      )

    updated_expanded_posts =
      Map.merge(
        socket.assigns.expanded_posts,
        Enum.into([{String.to_integer(post_id), post_replies}], %{})
      )

    {:noreply, assign(socket, expanded_posts: updated_expanded_posts)}
  end

  def handle_event("collapse_post", %{"post_id" => post_id}, socket) do
    {:noreply, update(socket, :expanded_posts, &Map.drop(&1, [String.to_integer(post_id)]))}
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
        />
      </div>
    </.header_with_sidebar_nav>
    """
  end

  attr :posts, :list
  attr :ctx, :map
  attr :section_slug, :string
  attr :expanded_posts, :map

  defp posts_section(assigns) do
    ~H"""
    <section id="posts" class="flex flex-col items-start px-40 w-full gap-6">
      <div role="posts header" class="flex justify-between items-center w-full self-stretch">
        <h3 class="text-2xl tracking-[0.02px] font-semibold dark:text-white">
          Posts
        </h3>
        <div role="posts actions" class="flex items-center justify-end gap-6">
          <div class="flex space-x-3">
            <button
              role="filter"
              class="flex items-center gap-[10px] px-[10px] py-[4px] hover:text-gray-400 dark:text-white dark:hover:text-white/50"
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
            </button>

            <button
              role="sort"
              class="flex items-center gap-[10px] px-[10px] py-[4px] hover:text-gray-400 dark:text-white dark:hover:text-white/50"
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
            </button>
          </div>

          <button
            role="new discussion"
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
        <%= for post <- @posts.course_posts do %>
          <div class="p-6">
            <.course_post
              post={post}
              ctx={@ctx}
              is_expanded={post.id in Map.keys(@expanded_posts)}
              is_reply={false}
              replies={Map.get(@expanded_posts, post.id, [])}
              expanded_posts={@expanded_posts}
            />
          </div>
        <% end %>
        <.page_post
          :for={post <- @posts.page_posts}
          post={post}
          ctx={@ctx}
          section_slug={@section_slug}
        />
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

  defp course_post(assigns) do
    ~H"""
    <div
      role="course post"
      id={"post-#{@post.id}"}
      class={[
        "flex flex-col gap-6",
        if(@is_reply, do: "border-l-8 border-gray-100 dark:border-gray-900/60 pl-3 pt-2")
      ]}
    >
      <div role="post header" class="flex items-center gap-2">
        <.avatar user_name={@post.user_name} />
        <div class="flex flex-col items-start gap-[1px]">
          <span class="text-[16px] leading-[22px] tracking-[0.02px] font-semibold dark:text-white">
            <%= @post.user_name %>
          </span>
          <span class="text-[14px] leading-[19px] tracking-[0.02px] dark:text-white/50">
            <%= FormatDateTime.parse_datetime(
              @post.updated_at,
              @ctx,
              "{WDshort}, {Mshort} {D}, {YYYY}"
            ) %>
          </span>
        </div>
      </div>
      <div role="post content" class="w-full">
        <p class={["text-[18px] leading-[25px] dark:text-white", if(!@is_expanded, do: "truncate")]}>
          <%= @post.content.message %>
        </p>
      </div>
      <div :if={!@is_expanded} role="post footer" class="flex justify-between items-center">
        <div role="reply details" class="flex gap-6 items-center">
          <div class="ml-[10px] flex items-center">
            <div class="relative h-8 w-8 flex items-center">
              <i class="fa-solid fa-message h-4 w-4" style="transform: scaleX(-1);" />
              <span
                :if={@post.unread_reply_count > 0}
                role="unread count"
                class="absolute -top-0.5 right-2 w-4 h-4 shrink-0 rounded-full bg-[#FF4B47] text-white text-[9px] font-bold flex items-center justify-center"
              >
                <%= @post.unread_reply_count %>
              </span>
            </div>
            <span class="text-[14px] leading-[22px] tracking-[0.02px] dark:text-white">
              <%= @post.reply_count %> <%= if @post.reply_count == 1, do: "reply", else: "replies" %>
            </span>
          </div>
          <div :if={@post.reply_count > 0} class="flex items-center gap-[6px]">
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
            />
          </div>
        <% end %>
        <input type="text" placeholder="Write a response..." />
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

  defp page_post(assigns) do
    ~H"""
    <div role="post-2" class="flex flex-col gap-6 p-6">
      <div role="post header" class="flex items-center gap-2">
        <.avatar user_name={@post.user_name} />
        <div class="flex flex-col items-start gap-[1px]">
          <span class="text-[16px] leading-[22px] tracking-[0.02px] font-semibold dark:text-white">
            <%= @post.user_name %>
          </span>
          <span class="text-[14px] leading-[19px] tracking-[0.02px] dark:text-white/50">
            <%= FormatDateTime.parse_datetime(
              @post.updated_at,
              @ctx,
              "{WDshort}, {Mshort} {D}, {YYYY}"
            ) %>
          </span>
        </div>
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
                :if={@post.unread_reply_count > 0}
                role="unread count"
                class="absolute -top-0.5 right-2 w-4 h-4 shrink-0 rounded-full bg-[#FF4B47] text-white text-[9px] font-bold flex items-center justify-center"
              >
                <%= @post.unread_reply_count %>
              </span>
            </div>
            <span class="text-[14px] leading-[22px] tracking-[0.02px] dark:text-white">
              <%= @post.reply_count %> <%= if @post.reply_count == 1, do: "reply", else: "replies" %>
            </span>
          </div>
          <div :if={@post.reply_count > 0} class="flex items-center gap-[6px]">
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

  attr :user_name, :string

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
      get_color_for_name(@user_name)
    ]}>
      <span class="text-[14px] text-white uppercase"><%= to_initials(@user_name) %></span>
    </div>
    """
  end

  # Generate a consistent color based on the user's name.
  defp get_color_for_name(user_name) do
    # Create a hash of the user name.
    hash = :erlang.phash2(user_name)

    # Use the hash to select a color.
    Enum.at(@colors, rem(hash, length(@colors)))
  end

  defp to_initials(user_name) do
    user_name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.slice(&1, 0..0))
    |> Enum.join()
  end
end
