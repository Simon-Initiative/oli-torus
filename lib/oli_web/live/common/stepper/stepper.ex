defmodule OliWeb.Common.Stepper do
  use Phoenix.LiveComponent

  alias OliWeb.Common.Stepper.Step

  @moduledoc """
  Stepper Component
  """

  @empty_step %Step{
    title: "",
    description: "",
    render_fn: &__MODULE__.render_unselected_step/1,
    data: %{}
  }

  attr :id, :string, required: true
  attr :steps, :list, required: true
  attr :current_step, :integer, default: 0
  attr :data, :map, default: %{}

  def render(assigns) do
    assigns = assign(assigns, steps: Enum.with_index(assigns.steps))

    assigns =
      assign(assigns,
        selected_step:
          Enum.find(assigns.steps, {@empty_step, 0}, fn {_step, index} ->
            index == assigns.current_step
          end)
          |> elem(0)
      )

    ~H"""
      <div id={@id} class="flex md:flex-row flex-col-reverse h-screen w-full">
        <div class="bg-delivery-body-color-dark dark:bg-gray-900 h-3/5 w-full md:h-full md:w-3/5" />
        <div class="bg-blue-700 h-2/5 w-full md:h-full md:w-2/5" />
        <div class="flex md:flex-row flex-col-reverse absolute p-16 top-0 bottom-0 left-0 right-0 m-auto">
          <div class="bg-white dark:bg-gray-800 w-full md:w-2/3 border border-gray-200 dark:border-gray-600 flex flex-col overflow-hidden">
            <%= @selected_step.render_fn.(@data) %>
            <div class="px-9 py-4 flex items-center justify-between border-gray-200 dark:border-gray-600 border-t">
              <button class="torus-button secondary">Cancel</button>
              <div class="flex gap-2">
                <%= if @current_step != 0 do %>
                  <button phx-click={@selected_step.on_previous_step} class="torus-button secondary">Previous step</button>
                <% end %>
                <button phx-click={@selected_step.on_next_step} class="torus-button primary">Next step</button>
              </div>
            </div>
          </div>
          <div class="w-full md:w-1/3 my-auto z-10">
            <div class="flex md:flex-col flex-row gap-4 md:-ml-7 scrollbar-hide overflow-x-auto md:overflow-x-hidden">
              <%= for {step, index} <- @steps do %>
                <.step index={index + 1} step={step} active={index == @current_step} />
              <% end %>
            </div>
          </div>
        </div>
      </div>
    """
  end

  def handle_event("change_step", %{"step" => step}, socket) do
    {:noreply, assign(socket, current_step: String.to_integer(step))}
  end

  def step(%{index: index, step: %Step{}, active: active} = assigns) do
    ~H"""
    <div class="flex gap-8 items-center shrink-0 w-80 md:w-auto">
      <div class={"flex shrink-0 items-center justify-center text-xl font-extrabold h-14 w-14 rounded-full shadow-sm #{if active, do: "bg-primary text-white", else: "bg-white dark:bg-gray-800 border text-gray-400 border-gray-300 dark:border-gray-600"}"}>
        <%= @index %>
      </div>
      <div class={"flex flex-col text-white #{if !active, do: "opacity-50"}"}>
        <h4 class="font-bold"><%= @step.title %></h4>
        <p class="font-normal"><%= @step.description %></p>
      </div>
    </div>
    """
  end

  def render_unselected_step(assigns) do
    ~H"""
    <h3>Invalid stepper index</h3>
    """
  end
end
