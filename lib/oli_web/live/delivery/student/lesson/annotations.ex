defmodule OliWeb.Delivery.Student.Lesson.Annotations do
  use OliWeb, :html

  def panel(assigns) do
    ~H"""
    <div class="flex-1 flex flex-row">
      <div class="justify-start">
        <.toggle_notes_button>
          <i class="fa-solid fa-xmark group-hover:scale-110"></i>
        </.toggle_notes_button>
      </div>
      <div class="flex-1 flex flex-col bg-white p-5">
        <.tab_group class="py-3">
          <.tab selected={true}><.user_icon class="mr-2" /> My Notes</.tab>
          <.tab><.users_icon class="mr-2" /> Class Notes</.tab>
        </.tab_group>
        <.search_box class="mt-2" />
        <hr class="m-6 border-b border-b-gray-200" />
        <div class="flex-1 flex flex-col gap-3">
          <.note></.note>
          <.note></.note>
        </div>
      </div>
    </div>
    """
  end

  slot :inner_block, required: true

  def toggle_notes_button(assigns) do
    ~H"""
    <button
      class="flex flex-col items-center rounded-l-lg bg-white px-6 py-12 text-xl group"
      phx-click="toggle_sidebar"
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  def annotations_icon(assigns) do
    ~H"""
    <svg
      width="24"
      height="25"
      viewBox="0 0 24 25"
      xmlns="http://www.w3.org/2000/svg"
      class="group-hover:scale-110"
    >
      <path
        id="Path"
        fill="#0064ed"
        fill-rule="evenodd"
        stroke="none"
        d="M 9.51568 1.826046 C 5.766479 1.826046 2.727119 4.889919 2.727119 8.669355 C 2.727119 9.763306 2.98112 10.79484 3.432001 11.709678 C 3.53856 11.925805 3.55584 12.175646 3.48008 12.404678 L 2.330881 15.88008 L 5.81328 14.748066 C 6.03848 14.674919 6.283121 14.693466 6.494881 14.799678 C 7.40368 15.255725 8.42864 15.51266 9.51568 15.51266 C 13.264959 15.51266 16.304239 12.448791 16.304239 8.669355 C 16.304239 4.889919 13.264959 1.826046 9.51568 1.826046 Z M 0.91568 8.669355 C 0.91568 3.881369 4.76608 0 9.51568 0 C 14.26536 0 18.115759 3.881369 18.115759 8.669355 C 18.115759 13.457338 14.26536 17.338711 9.51568 17.338711 C 8.276159 17.338711 7.09592 17.073872 6.02928 16.596533 L 1.183681 18.171612 C 0.85872 18.277258 0.5024 18.189596 0.26216 17.945 C 0.021919 17.700485 -0.06144 17.340405 0.04648 17.01387 L 1.6472 12.173065 C 1.17672 11.100726 0.91568 9.914679 0.91568 8.669355 Z"
      />
      <path
        id="path1"
        fill="#0064ed"
        fill-rule="evenodd"
        stroke="none"
        d="M 23.192719 16.158226 C 23.192719 11.929112 19.79184 8.500807 15.59664 8.500807 C 11.401441 8.500807 8.000481 11.929112 8.000481 16.158226 C 8.000481 20.387257 11.401441 23.815567 15.59664 23.815567 C 16.691441 23.815567 17.733999 23.581615 18.676081 23.16 L 22.955999 24.551207 C 23.243038 24.644514 23.55776 24.567179 23.77 24.351126 C 23.982239 24.135078 24.055841 23.817099 23.96048 23.528627 L 22.54664 19.252899 C 22.962162 18.305725 23.192719 17.258146 23.192719 16.158226 Z"
      />
    </svg>
    """
  end

  slot :inner_block, required: true
  attr :rest, :global, include: ~w(class)

  defp tab_group(assigns) do
    ~H"""
    <div class={["flex flex-row", @rest[:class]]}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  attr :selected, :boolean, default: false
  slot :inner_block, required: true

  defp tab(assigns) do
    ~H"""
    <button class={[
      "flex-1 inline-flex justify-center border-l border-t border-b first:rounded-l-lg last:rounded-r-lg last:border-r px-4 py-3 inline-flex items-center",
      if(@selected,
        do: "bg-primary border-primary text-white stroke-white font-semibold",
        else: "stroke-[#383A44] border-gray-400 hover:bg-gray-100"
      )
    ]}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  attr :rest, :global, include: ~w(class)

  defp user_icon(assigns) do
    ~H"""
    <svg
      class={@rest[:class]}
      width="20"
      height="20"
      viewBox="0 0 20 20"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M16.6666 17.5V15.8333C16.6666 14.9493 16.3154 14.1014 15.6903 13.4763C15.0652 12.8512 14.2173 12.5 13.3333 12.5H6.66659C5.78253 12.5 4.93468 12.8512 4.30956 13.4763C3.68444 14.1014 3.33325 14.9493 3.33325 15.8333V17.5"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
      <path
        d="M10.0001 9.16667C11.841 9.16667 13.3334 7.67428 13.3334 5.83333C13.3334 3.99238 11.841 2.5 10.0001 2.5C8.15913 2.5 6.66675 3.99238 6.66675 5.83333C6.66675 7.67428 8.15913 9.16667 10.0001 9.16667Z"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
    """
  end

  attr :rest, :global, include: ~w(class)

  defp users_icon(assigns) do
    ~H"""
    <svg
      class={@rest[:class]}
      width="20"
      height="20"
      viewBox="0 0 20 20"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <g clip-path="url(#clip0_270_13479)">
        <path
          d="M14.1666 17.5V15.8333C14.1666 14.9493 13.8154 14.1014 13.1903 13.4763C12.5652 12.8512 11.7173 12.5 10.8333 12.5H4.16659C3.28253 12.5 2.43468 12.8512 1.80956 13.4763C1.18444 14.1014 0.833252 14.9493 0.833252 15.8333V17.5"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
        <path
          d="M7.50008 9.16667C9.34103 9.16667 10.8334 7.67428 10.8334 5.83333C10.8334 3.99238 9.34103 2.5 7.50008 2.5C5.65913 2.5 4.16675 3.99238 4.16675 5.83333C4.16675 7.67428 5.65913 9.16667 7.50008 9.16667Z"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
        <path
          d="M19.1667 17.4991V15.8324C19.1662 15.0939 18.9204 14.3764 18.4679 13.7927C18.0154 13.209 17.3819 12.7921 16.6667 12.6074"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
        <path
          d="M13.3333 2.60742C14.0503 2.79101 14.6858 3.20801 15.1396 3.79268C15.5935 4.37736 15.8398 5.09645 15.8398 5.83659C15.8398 6.57673 15.5935 7.29582 15.1396 7.8805C14.6858 8.46517 14.0503 8.88217 13.3333 9.06576"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </g>
      <defs>
        <clipPath id="clip0_270_13479">
          <rect width="20" height="20" fill="white" />
        </clipPath>
      </defs>
    </svg>
    """
  end

  attr :rest, :global, include: ~w(class)

  defp search_box(assigns) do
    ~H"""
    <div class={["flex flex-row", @rest[:class]]}>
      <div class="flex-1 relative">
        <i class="fa-solid fa-search absolute left-4 top-4 text-gray-400 pointer-events-none text-lg">
        </i>
        <input type="text" class="w-full border border-gray-400 rounded-lg pl-12 pr-3 py-3" />
      </div>
    </div>
    """
  end

  defp note(assigns) do
    ~H"""
    <div class="flex flex-col p-4 border-2 border-gray-200 rounded">
      <div class="flex flex-row justify-between mb-3">
        <div class="font-semibold">
          Me
        </div>
        <div class="text-sm text-gray-500">
          1d
        </div>
      </div>
      <p>
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla nec dui in odio.
      </p>
    </div>
    """
  end

  attr :point_marker, :map

  def annotation_bubble(assigns) do
    ~H"""
    <button class="absolute right-[-15px] cursor-pointer group" style={"top: #{@point_marker.top}px"}>
      <.chat_bubble>
        +
      </.chat_bubble>
    </button>
    """
  end

  slot :inner_block

  def chat_bubble(assigns) do
    ~H"""
    <svg
      width="31"
      height="31"
      viewBox="0 0 31 31"
      fill="none"
      class="group-hover:scale-110 group-active:scale-100"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M30 14.6945C30.0055 16.8209 29.5087 18.9186 28.55 20.8167C27.4132 23.0912 25.6657 25.0042 23.5031 26.3416C21.3405 27.679 18.8483 28.3879 16.3055 28.3889C14.1791 28.3944 12.0814 27.8976 10.1833 26.9389L1 30L4.06111 20.8167C3.10239 18.9186 2.60556 16.8209 2.61111 14.6945C2.61209 12.1517 3.32098 9.65951 4.65837 7.49692C5.99577 5.33433 7.90884 3.58679 10.1833 2.45004C12.0814 1.49132 14.1791 0.994502 16.3055 1.00005H17.1111C20.4692 1.18531 23.641 2.60271 26.0191 4.98087C28.3973 7.35902 29.8147 10.5308 30 13.8889V14.6945Z"
        class="fill-white stroke-gray-300"
        stroke-width="1.61111"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
      <text x="11" y="22" class="text-xl fill-gray-500">
        <%= render_slot(@inner_block) %>
      </text>
    </svg>
    """
  end
end
