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
  attr :cancel_button_label, :string, default: "Cancel"
  attr :on_cancel, :any, default: nil
  attr :next_step_disabled, :boolean, default: false
  attr :show_spinner, :boolean, default: false

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
          <div class={"px-9 py-4 flex items-center border-gray-200 dark:border-gray-600 border-t #{if is_nil(@on_cancel), do: "justify-end", else: "justify-between"}"}>
            <%= if !is_nil(@on_cancel) do %>
              <button phx-click={@on_cancel} class="torus-button secondary">
                <%= @cancel_button_label %>
              </button>
            <% end %>
            <div class="flex gap-2">
              <%= if @current_step != 0 do %>
                <button phx-click={@selected_step.on_previous_step} class="torus-button secondary">
                  <%= @selected_step.previous_button_label || "Previous step" %>
                </button>
              <% end %>
              <button
                disabled={@next_step_disabled}
                phx-click={@selected_step.on_next_step}
                class="torus-button primary"
              >
                <%= @selected_step.next_button_label || "Next step" %>

                <div :if={@show_spinner} class="ml-1" role="status">
                  <svg
                    aria-hidden="true"
                    class="w-8 h-8 text-gray-200 animate-spin dark:text-gray-600 fill-blue-600"
                    viewBox="0 0 100 101"
                    fill="none"
                    xmlns="http://www.w3.org/2000/svg"
                  >
                    <path
                      d="M100 50.5908C100 78.2051 77.6142 100.591 50 100.591C22.3858 100.591 0 78.2051 0 50.5908C0 22.9766 22.3858 0.59082 50 0.59082C77.6142 0.59082 100 22.9766 100 50.5908ZM9.08144 50.5908C9.08144 73.1895 27.4013 91.5094 50 91.5094C72.5987 91.5094 90.9186 73.1895 90.9186 50.5908C90.9186 27.9921 72.5987 9.67226 50 9.67226C27.4013 9.67226 9.08144 27.9921 9.08144 50.5908Z"
                      fill="currentColor"
                    />
                    <path
                      d="M93.9676 39.0409C96.393 38.4038 97.8624 35.9116 97.0079 33.5539C95.2932 28.8227 92.871 24.3692 89.8167 20.348C85.8452 15.1192 80.8826 10.7238 75.2124 7.41289C69.5422 4.10194 63.2754 1.94025 56.7698 1.05124C51.7666 0.367541 46.6976 0.446843 41.7345 1.27873C39.2613 1.69328 37.813 4.19778 38.4501 6.62326C39.0873 9.04874 41.5694 10.4717 44.0505 10.1071C47.8511 9.54855 51.7191 9.52689 55.5402 10.0491C60.8642 10.7766 65.9928 12.5457 70.6331 15.2552C75.2735 17.9648 79.3347 21.5619 82.5849 25.841C84.9175 28.9121 86.7997 32.2913 88.1811 35.8758C89.083 38.2158 91.5421 39.6781 93.9676 39.0409Z"
                      fill="currentFill"
                    />
                  </svg>
                  <span class="sr-only">Loading...</span>
                </div>
              </button>
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

  def step(%{index: _index, step: %Step{}, active: _active} = assigns) do
    ~H"""
    <div class="flex gap-8 items-center shrink-0 w-80 md:w-auto">
      <div class={"flex shrink-0 items-center justify-center text-xl font-extrabold h-14 w-14 rounded-full shadow-sm #{if @active, do: "bg-primary text-white", else: "bg-white dark:bg-gray-800 border text-gray-400 border-gray-300 dark:border-gray-600"}"}>
        <%= @index %>
      </div>
      <div class={"flex flex-col text-white #{if !@active, do: "opacity-50"}"}>
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
