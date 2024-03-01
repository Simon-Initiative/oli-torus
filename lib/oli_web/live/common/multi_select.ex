defmodule OliWeb.Common.MultiSelect do
  alias Oli.Authoring.Course
  alias Oli.Delivery.Sections
  alias OliWeb.Common.MultiSelectOptions.SelectOption
  alias OliWeb.Common.MultiSelectOptions
  use OliWeb, :live_component
  alias Phoenix.LiveView.JS

  def update(params, socket) do
    %{options: options, initial_values: initial_values, id: id, label: label} =
      params
      |> IO.inspect(label: "parammsssss")

    IO.inspect(initial_values, label: "initial_value")

    socket =
      socket
      |> assign(id: id)
      |> assign(:section_ids, nil)
      |> assign(:product_ids, nil)
      |> assign(:label, label)
      |> assign(:disabled, options == [])
      |> assign(:options, options)
      |> assign(initial_values: initial_values)

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
        <div phx-click="click" phx-target={@myself}>click-me</div>

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

  def handle_event("click", _params, socket) do
    IO.inspect(socket.assigns.initial_values, label: "fjirfjhsf")

    project = Course.get_project_by_slug("proyecto")

    {sections, _products} =
      Sections.get_sections_by_base_project(project)
      |> Enum.reduce({[], []}, fn section, {sections, products} ->
        if section.type == :blueprint do
          {sections,
           products ++
             [
               %SelectOption{
                 id: section.id,
                 label: section.title,
                 selected: false,
                 is_product: true
               }
             ]}
        else
          {sections ++
             [
               %SelectOption{
                 id: section.id,
                 label: section.title,
                 selected: false,
                 is_product: false
               }
             ], products}
        end
      end)

    IO.inspect(sections, label: "fewfsfsde")
    # MultiSelectOptions.build_changeset(socket.assigns.initial_values)
    # |> to_form()
    form =
      MultiSelectOptions.build_changeset([
        %OliWeb.Common.MultiSelectOptions.SelectOption{
          id: 2,
          selected: false,
          label: "cursoelixir",
          is_product: false
        },
        %OliWeb.Common.MultiSelectOptions.SelectOption{
          id: 8,
          selected: false,
          label: "cursoruby",
          is_product: false
        },
        %OliWeb.Common.MultiSelectOptions.SelectOption{
          id: 9,
          selected: false,
          label: "cursorust",
          is_product: false
        },
        %OliWeb.Common.MultiSelectOptions.SelectOption{
          id: 6,
          selected: false,
          label: "cursojava",
          is_product: false
        }
      ])
      |> to_form()
      |> IO.inspect(label: "fffer")

    # |> Map.take([:value, :form])
    # |> IO.inspect(label: "ddl")

    # opt =
    #   Enum.map(options, fn option ->
    #     option.data.selected = false
    #   end)

    {:noreply, assign(socket, form: form)}
  end
end
