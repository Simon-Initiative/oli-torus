defmodule OliWeb.Common.MultiSelectInput do
  use OliWeb, :live_component
  alias Phoenix.LiveView.JS
  alias OliWeb.Icons

  def update(
        %{
          options: options,
          uuid: uuid,
          disabled: disabled,
          id: id,
          placeholder: placeholder,
          on_select_message: on_select_message
        },
        socket
      ) do
    {:ok,
     socket
     |> assign(id: id)
     |> assign(:placeholder, placeholder)
     |> assign(:disabled, disabled)
     |> assign(:options, options)
     |> assign(uuid: uuid)
     |> assign(on_select_message: on_select_message)
     |> assign(selected_values: %{})}
  end

  attr :placeholder, :string, default: "Select an option"
  attr :disabled, :boolean, default: false
  attr :options, :list, default: []
  attr :id, :string
  attr :on_select_message, :string, doc: "The message to send when an option is selected"
  attr :uuid, :string, default: UUID.uuid4()

  def render(assigns) do
    ~H"""
    <div class="flex flex-col border relative">
      <div
        phx-click={
          if(!@disabled,
            do:
              JS.toggle(to: "##{@id}-options-container")
              |> JS.toggle(to: "##{@id}-down-icon")
              |> JS.toggle(to: "##{@id}-up-icon")
          )
        }
        class={[
          "flex justify-between min-h-[40px] items-center p-2 w-96 hover:cursor-pointer",
          if(@disabled, do: "bg-gray-300 hover:cursor-not-allowed")
        ]}
        id={"#{@id}-selected-options-container"}
      >
        <div class="flex gap-1 flex-wrap">
          <span :if={@selected_values == %{}}>{@placeholder}</span>
          <div :for={{id, name} <- @selected_values} class="bg-blue-500 rounded-lg px-2 flex gap-1">
            <span class="whitespace-nowrap text-white">{name}</span>
            <div
              class="stroke-white hover:stroke-white/50 w-2 h-2 mr-2"
              phx-click="remove_selected"
              phx-value-id={id}
              phx-target={@myself}
            >
              <Icons.close />
            </div>
          </div>
        </div>
        <div id={"#{@id}-down-icon"}>
          <i class="fa-solid fa-chevron-up rotate-180"></i>
        </div>
        <div class="hidden" id={"#{@id}-up-icon"}>
          <i class="fa-solid fa-chevron-up"></i>
        </div>
      </div>
      <div class="relative">
        <div
          class="p-4 hidden absolute dark:bg-gray-700 bg-white w-96 border max-h-56 overflow-y-scroll"
          id={"#{@id}-options-container"}
          phx-click-away={
            JS.hide() |> JS.hide(to: "##{@id}-up-icon") |> JS.show(to: "##{@id}-down-icon")
          }
        >
          <div>
            <.form :let={_f} for={%{}} as={:options} phx-change="toggle_selected" phx-target={@myself}>
              <.input
                :for={option <- @options}
                name={option.id}
                value={option.selected}
                label={option.name}
                type="checkbox"
              />
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("remove_selected", %{"id" => id}, socket) do
    selected_id = String.to_integer(id)
    do_update_selection(socket, selected_id)
  end

  def handle_event("toggle_selected", %{"_target" => [id]}, socket) do
    selected_id = String.to_integer(id)
    do_update_selection(socket, selected_id)
  end

  defp do_update_selection(socket, selected_id) do
    updated_options =
      Enum.map(socket.assigns.options, fn option ->
        if option.id == selected_id do
          %{option | selected: !option.selected}
        else
          option
        end
      end)

    {selected_values, selected_ids} =
      Enum.reduce(updated_options, {%{}, []}, fn option, {values, acc_ids} ->
        if option.selected do
          {Map.put(values, option.id, option.name), [option.id | acc_ids]}
        else
          {values, acc_ids}
        end
      end)

    send(self(), {:option_selected, socket.assigns.on_select_message, selected_ids})

    {:noreply, assign(socket, selected_values: selected_values, options: updated_options)}
  end
end
