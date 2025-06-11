defmodule OliWeb.Delivery.Student.Learn.Components.ViewSelector do
  use OliWeb, :live_component

  @view_options [:outline, :gallery]

  def mount(socket) do
    {:ok, assign(socket, view_options: @view_options, expanded: false)}
  end

  attr :selected_view, :atom

  def render(%{expanded: true} = assigns) do
    ~H"""
    <div id={@id} class="relative w-48" phx-click-away="collapse_select" phx-target={@myself}>
      <button
        id="select_view_button"
        phx-click="collapse_select"
        phx-target={@myself}
        class="h-[36px] w-full justify-center items-center gap-2 inline-flex"
      >
        <div class="w-[114px] h-[36px] pl-2.5 pr-[7px] py-2.5 justify-center items-center gap-2.5 flex">
          <div class="dark:text-white text-base font-normal">View page as</div>
        </div>
        <div class="w-8 h-[36px] py-2.5 px-2.5 justify-center items-center flex gap-2.5 rotate-180">
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
          <div class="dark:text-white text-base font-normal">
            <%= to_capitalized_string(option) %>
          </div>
        </button>
      </div>
    </div>
    """
  end

  def render(%{expanded: false} = assigns) do
    ~H"""
    <div id={@id} class="w-48">
      <button
        phx-click="expand_select"
        phx-target={@myself}
        class="h-[36px] justify-center items-center gap-2 inline-flex"
      >
        <div class="h-[36px] pl-2.5 pr-[7px] py-2.5 justify-center items-center gap-[5px] flex">
          <div class="justify-center items-center flex"><.view_icon option={@selected_view} /></div>
          <div class="ml-1 dark:text-white text-base font-normal">
            <%= to_capitalized_string(@selected_view) %> View
          </div>
        </div>
        <div class="w-8 h-[36px] py-2.5 px-2.5 justify-center items-center gap-[5px] flex">
          <.chevron_icon />
        </div>
      </button>
    </div>
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
    <i class="ti ti-list"></i>
    """
  end

  defp view_icon(%{option: :gallery} = assigns) do
    ~H"""
    <i class="ti ti-layout-grid"></i>
    """
  end

  defp to_capitalized_string(atom) do
    atom
    |> Atom.to_string()
    |> String.capitalize()
  end
end
