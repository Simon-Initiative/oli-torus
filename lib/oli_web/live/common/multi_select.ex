defmodule OliWeb.Common.MultiSelect do
  use OliWeb, :live_component

  def update(params, socket) do
    %{options: options, form: form, id: id} = params

    socket =
      socket
      |> assign(:id, id)
      |> assign(:selectable_options, options)
      |> assign(:form, form)
      |> assign(:section_ids, nil)
      |> assign(:product_ids, nil)

    Enum.each(options, fn option ->
      if option.selected do
        IO.inspect("Hola")
      end
    end)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="multiselect">
      <div class="fake_select_tag" id={"#{@id}-selected-options-container"}>
        <div class="icon">
          <svg
            id={"#{@id}-down-icon"}
            phx-click={
              Phoenix.LiveView.JS.toggle()
              |> Phoenix.LiveView.JS.toggle(to: "##{@id}-up-icon")
              |> Phoenix.LiveView.JS.toggle(to: "##{@id}-options-container")
            }
          >
            <path
              fill-rule="evenodd"
              d="M1.646 4.646a.5.5 0 0 1 .708 0L8 10.293l5.646-5.647a.5.5 0 0 1 .708.708l-6 6a.5.5 0 0 1-.708 0l-6-6a.5.5 0 0 1 0-.708"
            />
          </svg>
          <svg
            id={"#{@id}-up-icon" }
            phx-click={
              Phoenix.LiveView.JS.toggle()
              |> Phoenix.LiveView.JS.toggle(to: "##{@id}-down-icon")
              |> Phoenix.LiveView.JS.toggle(to: "##{@id}-options-container")
            }
          >
            <path
              fill-rule="evenodd"
              d="M1.646 4.646a.5.5 0 0 1 .708 0L8 10.293l5.646-5.647a.5.5 0 0 1 .708.708l-6 6a.5.5 0 0 1-.708 0l-6-6a.5.5 0 0 1 0-.708"
            />
          </svg>
        </div>
      </div>
      <div id={"#{@id}-options-container"}>
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
    """
  end
end
