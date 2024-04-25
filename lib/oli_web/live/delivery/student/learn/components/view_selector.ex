defmodule OliWeb.Delivery.Student.Learn.Components.ViewSelector do
  use OliWeb, :live_component

  @view_options [:outline, :gallery]

  def mount(socket) do
    {:ok, assign(socket, view_options: @view_options, expanded: false)}
  end

  attr :selected_view, :atom

  def render(%{expanded: true} = assigns) do
    ~H"""
    <div class="relative" phx-click-away="collapse_select" phx-target={@myself}>
      <button
        id="select_view_button"
        phx-click="collapse_select"
        phx-target={@myself}
        class="h-[31px] justify-center items-center gap-2 inline-flex"
      >
        <div class="w-[114px] pl-2.5 pr-[7px] py-2.5 justify-center items-center gap-2.5 flex">
          <div class="dark:text-white text-base font-normal font-['Open Sans']">View page as</div>
        </div>
        <div class="w-8 h-[26px] px-2.5 justify-center items-center flex rotate-180">
          <.chevron_icon />
        </div>
      </button>

      <div class="absolute w-[171px] flex flex-col -ml-2 mt-2 bg-white shadow-lg dark:bg-black rounded-[5px] divide-y divide-gray-300 dark:divide-white/20 overflow-hidden">
        <button
          :for={option <- @view_options}
          phx-click={
            JS.push("change_selected_view") |> JS.dispatch("click", to: "#select_view_button")
          }
          phx-value-selected_view={option}
          class="flex gap-2 items-center h-[42px] px-[11px] w-full hover:bg-gray-300 hover:dark:bg-[#262626]"
        >
          <div class="w-6 flex items-center justify-center">
            <.view_icon option={option} />
          </div>
          <div class="dark:text-white text-base font-normal font-['Open Sans']">
            <%= to_capitalized_string(option) %>
          </div>
        </button>
      </div>
    </div>
    """
  end

  def render(%{expanded: false} = assigns) do
    ~H"""
    <button
      phx-click="expand_select"
      phx-target={@myself}
      class="h-[31px] justify-center items-center gap-2 inline-flex"
    >
      <div class="pl-2.5 pr-[7px] py-2.5 justify-center items-center gap-[5px] flex">
        <div class="justify-center items-center flex"><.view_icon option={@selected_view} /></div>
        <div class="ml-1 dark:text-white text-base font-normal font-['Open Sans']">
          <%= to_capitalized_string(@selected_view) %> View
        </div>
      </div>
      <div class="w-8 h-[26px] px-2.5 justify-center items-center flex"><.chevron_icon /></div>
    </button>
    """
  end

  def handle_event("expand_select", _, socket) do
    {:noreply, assign(socket, expanded: true)}
  end

  def handle_event("collapse_select", _, socket) do
    {:noreply, assign(socket, expanded: false)}
  end

  defp chevron_icon(assigns) do
    ~H"""
    <svg width="14" height="9" viewBox="0 0 14 9" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path
        d="M1 1.5L7 7.5L13 1.5"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="stroke-black/60 dark:stroke-white"
      />
    </svg>
    """
  end

  attr :option, :atom, required: true

  defp view_icon(%{option: :outline} = assigns) do
    ~H"""
    <svg width="16" height="20" viewBox="0 0 16 20" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path
        d="M5 5H11M5 9H11M5 13H9M1 3C1 2.46957 1.21071 1.96086 1.58579 1.58579C1.96086 1.21071 2.46957 1 3 1H13C13.5304 1 14.0391 1.21071 14.4142 1.58579C14.7893 1.96086 15 2.46957 15 3V17C15 17.5304 14.7893 18.0391 14.4142 18.4142C14.0391 18.7893 13.5304 19 13 19H3C2.46957 19 1.96086 18.7893 1.58579 18.4142C1.21071 18.0391 1 17.5304 1 17V3Z"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="stroke-black/60 dark:stroke-white"
      />
    </svg>
    """
  end

  defp view_icon(%{option: :gallery} = assigns) do
    ~H"""
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path
        d="M15 8H15.01M3 16L8 11C8.928 10.107 10.072 10.107 11 11L16 16M14 14L15 13C15.928 12.107 17.072 12.107 18 13L21 16M3 6C3 5.20435 3.31607 4.44129 3.87868 3.87868C4.44129 3.31607 5.20435 3 6 3H18C18.7956 3 19.5587 3.31607 20.1213 3.87868C20.6839 4.44129 21 5.20435 21 6V18C21 18.7956 20.6839 19.5587 20.1213 20.1213C19.5587 20.6839 18.7956 21 18 21H6C5.20435 21 4.44129 20.6839 3.87868 20.1213C3.31607 19.5587 3 18.7956 3 18V6Z"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="stroke-black/60 dark:stroke-white"
      />
    </svg>
    """
  end

  defp to_capitalized_string(atom) do
    atom
    |> Atom.to_string()
    |> String.capitalize()
  end
end
