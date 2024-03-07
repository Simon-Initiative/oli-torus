defmodule OliWeb.Common.MultiSelect do
  use OliWeb, :live_component
  alias Phoenix.LiveView.JS

  def update(params, socket) do
    %{
      options: options,
      uid: uid,
      form: form,
      id: id,
      label: label
    } =
      params

    socket =
      socket
      |> assign(form: form)
      |> assign(id: id)
      |> assign(:section_ids, nil)
      |> assign(:product_ids, nil)
      |> assign(:label, label)
      |> assign(:disabled, options == [])
      |> assign(:options, options)
      |> assign(uid: uid)

    {:ok, socket}
  end

  attr :label, :string, default: "Select an option"

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
          "flex justify-between h-10 items-center p-2 w-96 hover:cursor-pointer",
          if(@disabled, do: "bg-gray-300 hover:cursor-not-allowed")
        ]}
        id={"#{@id}-selected-options-container"}
      >
        <span><%= @label %></span>
        <div id={"#{@id}-down-icon"}>
          <i class="fa-solid fa-chevron-up rotate-180"></i>
        </div>
        <div class="hidden" id={"#{@id}-up-icon"}>
          <i class="fa-solid fa-chevron-up"></i>
        </div>
      </div>
      <div
        class="p-4 hidden absolute mt-10 dark:bg-gray-700 bg-white w-96 border max-h-56 overflow-y-scroll"
        id={"#{@id}-options-container"}
        phx-click-away={
          JS.hide() |> JS.hide(to: "##{@id}-up-icon") |> JS.show(to: "##{@id}-down-icon")
        }
      >
        <div id={@uid}>
          <.inputs_for :let={opt} field={@form[:options]}>
            <.input
              value={opt.data.selected}
              type="checkbox"
              label={opt.data.label}
              name={opt.data.label}
            />
          </.inputs_for>
        </div>
      </div>
    </div>
    """
  end
end
