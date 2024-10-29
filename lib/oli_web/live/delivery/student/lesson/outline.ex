defmodule OliWeb.Delivery.Student.Lesson.Outline do
  use OliWeb, :html

  def toggle_outline_button(assigns) do
    ~H"""
    <button
      class="flex flex-col items-center rounded-l-lg bg-white dark:bg-black text-xl group"
      phx-click="toggle_outline_sidebar"
    >
      <div class="p-1.5 rounded justify-start items-center gap-2.5 inline-flex">
        <%= render_slot(@inner_block) %>
      </div>
    </button>
    """
  end

  def outline_icon(assigns) do
    ~H"""
    <svg
      width="32"
      height="32"
      viewBox="0 0 32 32"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      class="group-hover:scale-110"
    >
      <g clip-path="url(#clip0_2001_36964)">
        <path
          d="M13.0833 11H22.25M13.0833 15.9958H22.25M13.0833 20.9917H22.25M9.75 11V11.0083M9.75 15.9958V16.0042M9.75 20.9917V21"
          stroke="#0D70FF"
          stroke-width="1.5"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </g>
      <defs>
        <clipPath id="clip0_2001_36964">
          <rect width="20" height="20" fill="white" transform="translate(6 6)" />
        </clipPath>
      </defs>
    </svg>
    """
  end

  def panel(assigns) do
    ~H"""
    PLACEHOLDER FOR OUTLINE PANEL
    """
  end
end
