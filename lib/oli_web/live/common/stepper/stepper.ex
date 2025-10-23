defmodule OliWeb.Common.Stepper do
  use OliWeb, :live_component

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
    <div id={@id} class="flex md:flex-row flex-col-reverse h-full w-full">
      <div class="bg-blue-700 dark:bg-black w-full h-full md:w-2/5" />
      <div class="dark:bg-gray-900 h-3/5 w-full md:h-full md:w-3/5" />
      <div class="flex md:flex-row flex-col-reverse absolute px-4 sm:px-16 lg:pl-24 lg:pr-16 xl:px-32 top-14 bottom-0 left-0 right-0 m-auto">
        <div class="w-full md:w-1/3 my-auto z-20">
          <div class="flex flex-col md:mt-auto gap-[42px] md:-mr-[30px] scrollbar-hide overflow-x-auto md:overflow-x-hidden">
            <%= for {step, index} <- @steps do %>
              <.step index={index + 1} step={step} active={index == @current_step} />
            <% end %>
          </div>
        </div>
        <div class={[
          "bg-white dark:bg-[#0B0C11] w-full h-4/5 md:h-none md:w-2/3 flex flex-col overflow-y-scroll shadow-xl",
          if(@id == "course_creation_stepper",
            do: "my-10",
            else: "mt-4 hvxs:my-8 hvmd:my-16 hvlg:my-20 hvxl:my-24"
          )
        ]}>
          <div id="stepper_content" class="flex flex-col h-[calc(100%-64px)] w-full">
            {@selected_step.render_fn.(@data)}
          </div>

          <div class={"p-3 flex items-center bg-gray-100/50 dark:bg-black #{if is_nil(@on_cancel), do: "justify-end", else: "justify-between"}"}>
            <%= if !is_nil(@on_cancel) do %>
              <button
                phx-click={@on_cancel}
                class="torus-button secondary !py-[10px] !px-5 !rounded-[3px] !text-sm flex items-center justify-center  dark:!text-white dark:!bg-black dark:hover:!bg-gray-900"
              >
                {@cancel_button_label}
              </button>
            <% end %>
            <div class="flex gap-2">
              <%= if @current_step != 0 do %>
                <button
                  phx-click={
                    @selected_step.on_previous_step |> fade_out_transition("stepper_content")
                  }
                  class="torus-button secondary !py-[10px] !px-5 !rounded-[3px] !text-sm flex items-center justify-center  dark:!text-white dark:!bg-black dark:hover:!bg-gray-900"
                >
                  <i class="fa-solid fa-arrow-left sm:mr-2"></i><span class="hidden sm:flex"><%= @selected_step.previous_button_label ||
                    "Previous step" %></span>
                </button>
              <% end %>
              <button
                disabled={@next_step_disabled}
                phx-click={@selected_step.on_next_step |> fade_out_transition("stepper_content")}
                class="torus-button primary !py-[10px] !px-5 !rounded-[3px] !text-sm flex items-center justify-center"
              >
                {@selected_step.next_button_label || "Next step"}

                <div :if={@show_spinner} class="ml-1" role="status">
                  <.loader />
                </div>
              </button>
            </div>
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
    <div class={[
      "gap-2 md:gap-6 items-center justify-between shrink-0 md:w-auto",
      if(!@active, do: "hidden md:flex", else: "flex")
    ]}>
      <div class={"flex flex-col text-white #{if !@active, do: "opacity-50"}"}>
        <h4 class="font-bold text-md md:text-[20px] tracking-[0.02px] md:leading-5 mb-[9px]">
          {@step.title}
        </h4>
        <p class="font-normal text-sm md:text-[16px] tracking-[0.02px] md:leading-[24px]">
          {@step.description}
        </p>
      </div>
      <div class={"flex self-start shrink-0 items-center justify-center font-extrabold text-lg h-[30px] w-[30px] sm:text-xl sm:h-[60px] sm:w-[60px] rounded-full shadow-sm #{if @active, do: "bg-primary text-white", else: "bg-white dark:bg-black border text-gray-400 border-gray-300 dark:border-gray-600"}"}>
        {@index}
      </div>
    </div>
    """
  end

  def render_unselected_step(assigns) do
    ~H"""
    <h3>Invalid stepper index</h3>
    """
  end

  defp fade_out_transition(%JS{} = js, target_id) do
    js
    |> JS.transition(
      {"ease-out duration-300", "opacity-0", "opacity-100"},
      to: "##{target_id}",
      time: 300
    )
    |> JS.remove_class("opacity-100", to: "##{target_id}")
  end
end
