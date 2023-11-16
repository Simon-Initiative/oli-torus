defmodule OliWeb.Delivery.Student.DiscussionsLive do
  use OliWeb, :live_view

  import OliWeb.Components.Delivery.Layouts

  def mount(
        _params,
        _session,
        socket
      ) do
    {:ok, socket}
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
        <.posts_section />
      </div>
    </.header_with_sidebar_nav>
    """
  end

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
        <.class_post />
        <.page_post />
      </div>
    </section>
    """
  end

  _docp = """
  A class post is not associated with a page
  """

  defp class_post(assigns) do
    ~H"""
    <div role="post-1" class="flex flex-col gap-6 p-6">
      <div role="post header" class="flex items-center gap-2">
        <div class="w-8 h-8 rounded-full flex items-center justify-center shrink-0 bg-[#29BFFF]">
          <span class="text-[14px] text-white">DH</span>
        </div>
        <div class="flex flex-col items-start gap-[1px]">
          <span class="text-[16px] leading-[22px] tracking-[0.02px] font-semibold dark:text-white">
            Darnell Harris
          </span>
          <span class="text-[14px] leading-[19px] tracking-[0.02px] dark:text-white/50">
            Mon, Oct 12th, 2023
          </span>
        </div>
      </div>
      <div role="post content" class="w-full">
        <p class="truncate text-[18px] leading-[25px] dark:text-white">
          Hey, everyone! I've been trying to wrap my head around the concept of chemical bonding. It's so fascinating, but also a bit confusing.
        </p>
      </div>
      <div role="post footer" class="flex justify-between items-center">
        <div role="reply details" class="flex gap-6 items-center">
          <div class="ml-[10px] flex items-center">
            <div class="relative h-8 w-8 flex items-center">
              <i class="fa-solid fa-message h-4 w-4" style="transform: scaleX(-1);" />
              <span
                role="unread count"
                class="absolute -top-0.5 right-2 w-4 h-4 shrink-0 rounded-full bg-[#FF4B47] text-white text-[9px] font-bold flex items-center justify-center"
              >
                2
              </span>
            </div>
            <span class="text-[14px] leading-[22px] tracking-[0.02px] dark:text-white">
              3 replies
            </span>
          </div>
          <div class="flex items-center gap-[6px]">
            <span class="text-[14px] font-semibold leading-[22px] tracking-[0.02px] dark:text-white">
              Last Reply:
            </span>
            <span class="text-[14px] leading-[19px] tracking-[0.02px] dark:text-white/50">
              Tue 20 Sep, 2024
            </span>
          </div>
        </div>
        <button class="text-[14px] leading-[20px] text-[#468AEF] hover:text-[#468AEF]/70">
          Open
        </button>
      </div>
    </div>
    """
  end

  _docp = """
  A page post is associated with a page, so it renders additional information,
  as the page title and the container it belongs to.
  """

  defp page_post(assigns) do
    ~H"""
    <div role="post-2" class="flex flex-col gap-6 p-6">
      <div role="post header" class="flex items-center gap-2">
        <div class="w-8 h-8 rounded-full flex items-center justify-center shrink-0 bg-[#FF9029]">
          <span class="text-[14px] text-white">CR</span>
        </div>
        <div class="flex flex-col items-start gap-[1px]">
          <span class="text-[16px] leading-[22px] tracking-[0.02px] font-semibold dark:text-white">
            Carmela Ruis
          </span>
          <span class="text-[14px] leading-[19px] tracking-[0.02px] dark:text-white/50">
            Mon, Oct 11th, 2023
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
            — The Wave-Particle Duality of Matter
          </span>
        </div>
        <span class="text-[14px] leading-[19px] truncate dark:text-white">
          Interference pattern? How does this experiment demonstrate that particles have wave-like properties?
        </span>
      </div>
      <div role="post content" class="w-full">
        <p class="truncate text-[18px] leading-[25px] dark:text-white">
          I'm confused about how particles like electrons create an interference pattern. If they are particles, shouldn't they pass through one slit or the other and create two distinct lines, rather than an interference pattern? How does this experiment demonstrate that particles have wave-like properties?
        </p>
      </div>
      <div role="post footer" class="flex justify-between items-center">
        <div role="reply details" class="flex gap-6 items-center">
          <div class="ml-[10px] flex items-center">
            <div class="relative h-8 w-8 flex items-center">
              <i class="fa-solid fa-message h-4 w-4" style="transform: scaleX(-1);" />
              <span
                role="unread count"
                class="hidden absolute -top-0.5 right-2 w-4 h-4 shrink-0 rounded-full bg-[#FF4B47] text-white text-[9px] font-bold flex items-center justify-center"
              >
                2
              </span>
            </div>
            <span class="text-[14px] leading-[22px] tracking-[0.02px] dark:text-white">
              4 replies
            </span>
          </div>
          <div class="flex items-center gap-[6px]">
            <span class="text-[14px] font-semibold leading-[22px] tracking-[0.02px] dark:text-white">
              Last Reply:
            </span>
            <span class="text-[14px] leading-[19px] tracking-[0.02px] dark:text-white/50">
              Tue 20 Sep, 2024
            </span>
          </div>
        </div>
        <button class="flex items-center gap-1 text-[14px] leading-[20px] text-[#468AEF] hover:text-[#468AEF]/70">
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
        </button>
      </div>
    </div>
    """
  end
end
