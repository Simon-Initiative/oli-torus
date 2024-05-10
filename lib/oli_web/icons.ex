defmodule OliWeb.Icons do
  @moduledoc """
  A collection of icons used in the OliWeb application.
  """

  use Phoenix.Component

  ########## Studend Delivery Icons (start) ##########

  attr :fill_class, :string, default: "fill-[#FF9040]"

  def flag(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="currentColor"
      class="icon icon-tabler icons-tabler-filled icon-tabler-flag-3"
    >
      <path stroke="none" d="M0 0h24v24H0z" fill="none" />
      <path
        d="M19 4c.852 0 1.297 .986 .783 1.623l-.076 .084l-3.792 3.793l3.792 3.793c.603 .602 .22 1.614 -.593 1.701l-.114 .006h-13v6a1 1 0 0 1 -.883 .993l-.117 .007a1 1 0 0 1 -.993 -.883l-.007 -.117v-16a1 1 0 0 1 .883 -.993l.117 -.007h14z"
        class={@fill_class}
      />
    </svg>
    """
  end

  def square_checked(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
      <path
        d="M5 21C4.45 21 3.97917 20.8042 3.5875 20.4125C3.19583 20.0208 3 19.55 3 19V5C3 4.45 3.19583 3.97917 3.5875 3.5875C3.97917 3.19583 4.45 3 5 3H17.925L15.925 5H5V19H19V12.05L21 10.05V19C21 19.55 20.8042 20.0208 20.4125 20.4125C20.0208 20.8042 19.55 21 19 21H5Z"
        class="fill-[#0CAF61] dark:fill-[#12E56A]"
      />
      <path
        d="M11.7 16.025L6 10.325L7.425 8.9L11.7 13.175L20.875 4L22.3 5.425L11.7 16.025Z"
        class="fill-[#0CAF61] dark:fill-[#12E56A]"
      />
    </svg>
    """
  end

  def exploration(assigns) do
    ~H"""
    <svg
      width="21"
      height="20"
      viewBox="0 0 21 20"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      class="m-1 fill-[#b982ff] group-[.past-start]:fill-[#e3cdff] dark:group-[.past-start]:fill-[#66488c]"
    >
      <path d="M10 20C8.61667 20 7.31667 19.7375 6.1 19.2125C4.88333 18.6875 3.825 17.975 2.925 17.075C2.025 16.175 1.3125 15.1167 0.7875 13.9C0.2625 12.6833 0 11.3833 0 10C0 8.61667 0.2625 7.31667 0.7875 6.1C1.3125 4.88333 2.025 3.825 2.925 2.925C3.825 2.025 4.88333 1.3125 6.1 0.7875C7.31667 0.2625 8.61667 0 10 0C12.4333 0 14.5625 0.7625 16.3875 2.2875C18.2125 3.8125 19.35 5.725 19.8 8.025H17.75C17.4333 6.80833 16.8625 5.72083 16.0375 4.7625C15.2125 3.80417 14.2 3.08333 13 2.6V3C13 3.55 12.8042 4.02083 12.4125 4.4125C12.0208 4.80417 11.55 5 11 5H9V7C9 7.28333 8.90417 7.52083 8.7125 7.7125C8.52083 7.90417 8.28333 8 8 8H6V10H8V13H7L2.2 8.2C2.15 8.5 2.10417 8.8 2.0625 9.1C2.02083 9.4 2 9.7 2 10C2 12.1833 2.76667 14.0583 4.3 15.625C5.83333 17.1917 7.73333 17.9833 10 18V20ZM19.1 19.5L15.9 16.3C15.55 16.5 15.175 16.6667 14.775 16.8C14.375 16.9333 13.95 17 13.5 17C12.25 17 11.1875 16.5625 10.3125 15.6875C9.4375 14.8125 9 13.75 9 12.5C9 11.25 9.4375 10.1875 10.3125 9.3125C11.1875 8.4375 12.25 8 13.5 8C14.75 8 15.8125 8.4375 16.6875 9.3125C17.5625 10.1875 18 11.25 18 12.5C18 12.95 17.9333 13.375 17.8 13.775C17.6667 14.175 17.5 14.55 17.3 14.9L20.5 18.1L19.1 19.5ZM13.5 15C14.2 15 14.7917 14.7583 15.275 14.275C15.7583 13.7917 16 13.2 16 12.5C16 11.8 15.7583 11.2083 15.275 10.725C14.7917 10.2417 14.2 10 13.5 10C12.8 10 12.2083 10.2417 11.725 10.725C11.2417 11.2083 11 11.8 11 12.5C11 13.2 11.2417 13.7917 11.725 14.275C12.2083 14.7583 12.8 15 13.5 15Z" />
    </svg>
    """
  end

  def bullet(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class="m-2"
      width="8"
      height="8"
      viewBox="0 0 8 8"
      fill="none"
    >
      <circle
        cx="4"
        cy="4"
        r="4"
        class="fill-gray-700 dark:fill-white group-[.past-start]:fill-gray-300 dark:group-[.past-start]:fill-gray-700"
      />
    </svg>
    """
  end

  attr :progress, :float, default: 1.0, doc: "1.0 == 100% progress"
  attr :role, :string, default: "check icon"

  def check(assigns) do
    ~H"""
    <div role="check icon" class="flex justify-center items-center w-[22px] h-[22px] shrink-0">
      <svg
        :if={@progress == 1.0}
        xmlns="http://www.w3.org/2000/svg"
        role={@role}
        width="24"
        height="24"
        viewBox="0 0 24 24"
        fill="none"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="icon icon-tabler icons-tabler-outline icon-tabler-check stroke-[#0CAF61] dark:stroke-[#12E56A]"
      >
        <path stroke="none" d="M0 0h24v24H0z" fill="none" />
        <path d="M5 12l5 5l10 -10" />
      </svg>
    </div>
    """
  end

  def clock(assigns) do
    ~H"""
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
      class="icon icon-tabler icons-tabler-outline icon-tabler-clock"
      role="clock icon"
    >
      <path stroke="none" d="M0 0h24v24H0z" fill="none" />
      <path d="M3 12a9 9 0 1 0 18 0a9 9 0 0 0 -18 0" />
      <path d="M12 7v5l3 3" />
    </svg>
    """
  end

  def time(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="18"
      height="18"
      viewBox="0 0 18 18"
      fill="none"
      role="time icon"
    >
      <g opacity="0.8">
        <path
          class="fill-black dark:fill-white"
          d="M11.475 12.525L12.525 11.475L9.75 8.7V5.25H8.25V9.3L11.475 12.525ZM9 16.5C7.9625 16.5 6.9875 16.3031 6.075 15.9094C5.1625 15.5156 4.36875 14.9813 3.69375 14.3063C3.01875 13.6313 2.48438 12.8375 2.09063 11.925C1.69688 11.0125 1.5 10.0375 1.5 9C1.5 7.9625 1.69688 6.9875 2.09063 6.075C2.48438 5.1625 3.01875 4.36875 3.69375 3.69375C4.36875 3.01875 5.1625 2.48438 6.075 2.09063C6.9875 1.69688 7.9625 1.5 9 1.5C10.0375 1.5 11.0125 1.69688 11.925 2.09063C12.8375 2.48438 13.6313 3.01875 14.3063 3.69375C14.9813 4.36875 15.5156 5.1625 15.9094 6.075C16.3031 6.9875 16.5 7.9625 16.5 9C16.5 10.0375 16.3031 11.0125 15.9094 11.925C15.5156 12.8375 14.9813 13.6313 14.3063 14.3063C13.6313 14.9813 12.8375 15.5156 11.925 15.9094C11.0125 16.3031 10.0375 16.5 9 16.5ZM9 15C10.6625 15 12.0781 14.4156 13.2469 13.2469C14.4156 12.0781 15 10.6625 15 9C15 7.3375 14.4156 5.92188 13.2469 4.75313C12.0781 3.58438 10.6625 3 9 3C7.3375 3 5.92188 3.58438 4.75313 4.75313C3.58438 5.92188 3 7.3375 3 9C3 10.6625 3.58438 12.0781 4.75313 13.2469C5.92188 14.4156 7.3375 15 9 15Z"
        />
      </g>
    </svg>
    """
  end

  def star(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="16"
      height="16"
      viewBox="0 0 16 16"
      fill="none"
      role="star icon"
    >
      <path
        d="M3.88301 14.0007L4.96634 9.31732L1.33301 6.16732L6.13301 5.75065L7.99967 1.33398L9.86634 5.75065L14.6663 6.16732L11.033 9.31732L12.1163 14.0007L7.99967 11.5173L3.88301 14.0007Z"
        fill="#0CAF61"
      />
    </svg>
    """
  end

  def practice_page(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" width="18" height="20" viewBox="0 0 18 20" fill="none">
      <path
        d="M3.34359 15.9558C2.54817 15.1604 1.89985 14.3023 1.39862 13.3816C0.897394 12.4608 0.537819 11.5183 0.319895 10.554C0.107418 9.58968 0.0338689 8.64171 0.0992462 7.71008C0.170072 6.77846 0.382548 5.90131 0.736675 5.07865C1.09625 4.25053 1.59203 3.51776 2.22401 2.88034C2.88323 2.22111 3.63507 1.71989 4.47952 1.37666C5.32943 1.03343 6.22292 0.842744 7.15999 0.804607C8.09707 0.761023 9.03414 0.864537 9.97122 1.11515C10.9083 1.36576 11.7963 1.75258 12.6353 2.2756L11.2216 3.66486C10.6223 3.34342 9.97939 3.10098 9.29293 2.93754C8.61191 2.76865 7.92545 2.69782 7.23354 2.72506C6.54708 2.74686 5.88786 2.88034 5.25588 3.1255C4.62935 3.37067 4.06819 3.74114 3.57241 4.23691C2.93499 4.87434 2.49096 5.62891 2.24035 6.5006C1.99519 7.3723 1.92981 8.2903 2.04422 9.25462C2.15863 10.2189 2.43921 11.1642 2.88595 12.0904C3.33815 13.0165 3.94016 13.8555 4.692 14.6074C5.15509 15.0759 5.63725 15.4709 6.13847 15.7923C6.64515 16.1138 7.1382 16.3753 7.61763 16.5769C8.09707 16.7839 8.54109 16.9446 8.94969 17.059C9.36375 17.1789 9.71243 17.2715 9.99573 17.3369C10.2954 17.4132 10.5187 17.533 10.6658 17.6965C10.8184 17.8654 10.8919 18.0833 10.8865 18.3502C10.8756 18.6608 10.7557 18.8896 10.5269 19.0367C10.2981 19.1892 10.0012 19.2383 9.63616 19.1838C9.33106 19.1402 8.94152 19.0558 8.46754 18.9305C7.999 18.8052 7.47598 18.6199 6.89848 18.3748C6.32643 18.135 5.73531 17.8163 5.12512 17.4186C4.51494 17.0209 3.92109 16.5333 3.34359 15.9558ZM6.63697 13.4061L8.68819 12.6215C9.11859 13.0465 9.60619 13.4006 10.151 13.6839C10.7013 13.9672 11.2706 14.1552 11.859 14.2478C12.4474 14.3404 13.0194 14.3132 13.5751 14.1661C14.1308 14.0135 14.6348 13.7112 15.087 13.259C15.5719 12.7795 15.8715 12.202 15.9859 11.5265C16.1058 10.8455 16.0595 10.1236 15.847 9.36086C15.6345 8.59267 15.2777 7.84084 14.7764 7.10534L16.1575 5.73242C16.7296 6.52784 17.16 7.34233 17.4487 8.17589C17.7429 9.00401 17.9009 9.81305 17.9227 10.603C17.9445 11.393 17.8301 12.1312 17.5795 12.8177C17.3343 13.4987 16.9557 14.098 16.4436 14.6156C15.9423 15.1168 15.3621 15.4873 14.7029 15.727C14.0491 15.9612 13.3572 16.0756 12.6272 16.0702C11.9026 16.0702 11.178 15.964 10.4534 15.7515C9.72877 15.539 9.03686 15.2339 8.37764 14.8362C7.72387 14.4385 7.14365 13.9618 6.63697 13.4061ZM8.35313 11.7716L6.38364 12.5153C6.24199 12.5698 6.10851 12.5398 5.9832 12.4254C5.86334 12.311 5.83338 12.1748 5.89331 12.0168L6.66149 10.0718L14.0982 2.64334L15.7898 4.33498L8.35313 11.7716ZM16.4191 3.7139L14.7274 2.02226L15.5119 1.23773C15.7244 1.0307 15.9696 0.91357 16.2474 0.886329C16.5307 0.859088 16.7623 0.938086 16.9421 1.12332L17.2363 1.40935C17.4487 1.62182 17.5441 1.87244 17.5223 2.16119C17.5059 2.44449 17.3915 2.69782 17.1791 2.9212L16.4191 3.7139Z"
        fill="white"
      />
    </svg>
    """
  end

  def up_arrow(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="12"
      height="6"
      viewBox="0 0 12 6"
      fill="currentColor"
    >
      <path d="M6 0L0 6H12L6 0Z" fill="currentColor" />
    </svg>
    """
  end

  attr :class, :string, default: ""

  def right_arrow(assigns) do
    ~H"""
    <svg
      class={@class}
      xmlns="http://www.w3.org/2000/svg"
      width="12"
      height="27"
      viewBox="0 0 12 27"
      fill="none"
    >
      <path d="M12 13.5L0 27L-1.18021e-06 1.90735e-06L12 13.5Z" />
    </svg>
    """
  end

  def down_arrow(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="27"
      height="12"
      viewBox="0 0 27 12"
      fill="currentColor"
    >
      <path d="M0 0L27 0L13.5 12Z" />
    </svg>
    """
  end

  attr :class, :string, default: ""

  def close(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
      <path class={@class} d="M6 18L18 6M6 6L18 18" stroke-width="2" stroke-linejoin="round" />
    </svg>
    """
  end

  attr :class, :string, default: ""

  def learning_objectives(assigns) do
    ~H"""
    <svg
      class={@class}
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
    >
      <path
        opacity="0.5"
        fill-rule="evenodd"
        clip-rule="evenodd"
        d="M20.5 15L23.5 12L20.5 9V5C20.5 4.45 20.3042 3.97917 19.9125 3.5875C19.5208 3.19583 19.05 3 18.5 3H4.5C3.95 3 3.47917 3.19583 3.0875 3.5875C2.69583 3.97917 2.5 4.45 2.5 5V19C2.5 19.55 2.69583 20.0208 3.0875 20.4125C3.47917 20.8042 3.95 21 4.5 21H18.5C19.05 21 19.5208 20.8042 19.9125 20.4125C20.3042 20.0208 20.5 19.55 20.5 19V15ZM10.5 14.15H12.35C12.35 13.8667 12.3625 13.625 12.3875 13.425C12.4125 13.225 12.4667 13.0333 12.55 12.85C12.6333 12.6667 12.7375 12.4958 12.8625 12.3375C12.9875 12.1792 13.1667 11.9833 13.4 11.75C13.9833 11.1667 14.3958 10.6792 14.6375 10.2875C14.8792 9.89583 15 9.45 15 8.95C15 8.06667 14.7 7.35417 14.1 6.8125C13.5 6.27083 12.6917 6 11.675 6C10.7583 6 9.97917 6.225 9.3375 6.675C8.69583 7.125 8.25 7.75 8 8.55L9.65 9.2C9.76667 8.75 10 8.3875 10.35 8.1125C10.7 7.8375 11.1083 7.7 11.575 7.7C12.025 7.7 12.4 7.82083 12.7 8.0625C13 8.30417 13.15 8.625 13.15 9.025C13.15 9.30833 13.0583 9.60833 12.875 9.925C12.6917 10.2417 12.3833 10.5917 11.95 10.975C11.6667 11.2083 11.4375 11.4375 11.2625 11.6625C11.0875 11.8875 10.9417 12.125 10.825 12.375C10.7083 12.625 10.625 12.8875 10.575 13.1625C10.525 13.4375 10.5 13.7667 10.5 14.15ZM11.4 18C11.75 18 12.0458 17.8792 12.2875 17.6375C12.5292 17.3958 12.65 17.1 12.65 16.75C12.65 16.4 12.5292 16.1042 12.2875 15.8625C12.0458 15.6208 11.75 15.5 11.4 15.5C11.05 15.5 10.7542 15.6208 10.5125 15.8625C10.2708 16.1042 10.15 16.4 10.15 16.75C10.15 17.1 10.2708 17.3958 10.5125 17.6375C10.7542 17.8792 11.05 18 11.4 18Z"
      />
    </svg>
    """
  end

  def chevron_down(assigns) do
    ~H"""
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path
        d="M6.70711 8.29289C6.31658 7.90237 5.68342 7.90237 5.29289 8.29289C4.90237 8.68342 4.90237 9.31658 5.29289 9.70711L11.2929 15.7071C11.6834 16.0976 12.3166 16.0976 12.7071 15.7071L18.7071 9.70711C19.0976 9.31658 19.0976 8.68342 18.7071 8.29289C18.3166 7.90237 17.6834 7.90237 17.2929 8.29289L12 13.5858L6.70711 8.29289Z"
        fill="white"
      />
    </svg>
    """
  end

  attr :class, :string, default: ""

  def filled_chevron_up(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="currentColor"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      class={@class}
    >
      <path d="M12 8l-6 6h12l-6-6z" />
    </svg>
    """
  end

  attr :class, :string, default: ""
  attr :path_class, :string, default: ""

  def video(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" class={@class}>
      <path
        d="M9.5 16.5L16.5 12L9.5 7.5V16.5ZM4 20C3.45 20 2.97917 19.8042 2.5875 19.4125C2.19583 19.0208 2 18.55 2 18V6C2 5.45 2.19583 4.97917 2.5875 4.5875C2.97917 4.19583 3.45 4 4 4H20C20.55 4 21.0208 4.19583 21.4125 4.5875C21.8042 4.97917 22 5.45 22 6V18C22 18.55 21.8042 19.0208 21.4125 19.4125C21.0208 19.8042 20.55 20 20 20H4Z"
        class={@path_class}
      />
    </svg>
    """
  end

  attr :class, :string, default: ""

  def play(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="white"
      width="33"
      height="38"
      viewBox="0 0 16.984 24.8075"
      class={@class}
    >
      <path d="M0.759,0.158c0.39-0.219,0.932-0.21,1.313,0.021l14.303,8.687c0.368,0.225,0.609,0.625,0.609,1.057   s-0.217,0.832-0.586,1.057L2.132,19.666c-0.382,0.231-0.984,0.24-1.375,0.021C0.367,19.468,0,19.056,0,18.608V1.237   C0,0.79,0.369,0.378,0.759,0.158z" />
    </svg>
    """
  end

  attr :class, :string, default: ""

  def plus(assigns) do
    ~H"""
    <svg
      role="plus icon"
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      stroke-width="1.5"
      stroke="currentColor"
      class={@class}
    >
      <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
    </svg>
    """
  end

  attr :rest, :global, include: ~w(class)

  def trash(assigns) do
    ~H"""
    <svg
      class={[@rest[:class]]}
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M3 6H5H21"
        stroke="black"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
      <path
        d="M19 6V20C19 20.5304 18.7893 21.0391 18.4142 21.4142C18.0391 21.7893 17.5304 22 17 22H7C6.46957 22 5.96086 21.7893 5.58579 21.4142C5.21071 21.0391 5 20.5304 5 20V6M8 6V4C8 3.46957 8.21071 2.96086 8.58579 2.58579C8.96086 2.21071 9.46957 2 10 2H14C14.5304 2 15.0391 2.21071 15.4142 2.58579C15.7893 2.96086 16 3.46957 16 4V6"
        stroke="black"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
      <path
        d="M10 11V17"
        stroke="black"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
      <path
        d="M14 11V17"
        stroke="black"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
    """
  end

  ########## Studend Delivery Icons (end) ##########
end