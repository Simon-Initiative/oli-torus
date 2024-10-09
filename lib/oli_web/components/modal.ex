defmodule OliWeb.Components.Modal do
  use Phoenix.Component

  import OliWeb.Components.Common
  import OliWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        Are you sure?
        <:confirm>OK</:confirm>
        <:cancel>Cancel</:cancel>
      </.modal>

  JS commands may be passed to the `:on_cancel` and `on_confirm` attributes
  for the caller to react to each button press, for example:

      <.modal id="confirm" on_confirm={JS.push("delete")} on_cancel={JS.navigate(~p"/posts")}>
        Are you sure you?
        <:confirm>OK</:confirm>
        <:cancel>Cancel</:cancel>
      </.modal>
  """
  attr :id, :string, required: true
  attr :class, :string, default: ""
  attr :body_class, :string, default: "p-6 space-y-6"
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  attr :on_confirm, JS, default: %JS{}

  slot :inner_block, required: true
  slot :title
  slot :subtitle
  slot :confirm
  slot :cancel
  slot :custom_footer

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="fixed inset-0 bg-black/20 transition-opacity backdrop-blur-sm"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class={["w-full p-4 sm:p-6 lg:py-8", @class]}>
            <.focus_wrap
              id={"#{@id}-container"}
              phx-mounted={@show && show_modal(@id)}
              phx-window-keydown={hide_modal(@on_cancel, @id)}
              phx-key="escape"
              phx-click-away={hide_modal(@on_cancel, @id)}
              class="hidden relative bg-white dark:bg-body-dark shadow-lg shadow-zinc-700/10 ring-1 ring-zinc-700/10 transition"
            >
              <!-- Modal header -->
              <div class="flex items-start justify-between p-4">
                <div>
                  <div :if={@title != []}>
                    <h1
                      id={"#{@id}-title"}
                      class="text-xl font-semibold text-gray-900 dark:text-white"
                    >
                      <%= render_slot(@title) %>
                    </h1>
                    <p
                      :if={@subtitle != []}
                      id={"#{@id}-description"}
                      class="mt-2 text-sm leading-6 text-zinc-600"
                    >
                      <%= render_slot(@subtitle) %>
                    </p>
                  </div>
                </div>
                <button
                  type="button"
                  class="text-gray-400 bg-transparent hover:bg-gray-200 hover:text-gray-900 rounded-lg text-sm w-8 h-8 ml-auto inline-flex justify-center items-center dark:hover:bg-gray-600 dark:hover:text-white"
                  phx-click={hide_modal(@on_cancel, @id)}
                  aria-label={gettext("close")}
                >
                  <svg
                    class="w-3 h-3"
                    aria-hidden="true"
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 14 14"
                  >
                    <path
                      stroke="currentColor"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="m1 1 6 6m0 0 6 6M7 7l6-6M7 7l-6 6"
                    />
                  </svg>
                  <span class="sr-only">Close modal</span>
                </button>
              </div>
              <!-- Modal body -->
              <div class={@body_class}>
                <%= render_slot(@inner_block) %>
              </div>
              <!-- Modal footer -->
              <%= render_slot(@custom_footer) %>
              <div :if={@confirm != [] or @cancel != []}>
                <div class="flex justify-end p-6 space-x-2">
                  <.button
                    :for={cancel <- @cancel}
                    phx-click={hide_modal(@on_cancel, @id)}
                    class="bg-transparent text-blue-500 hover:underline hover:bg-transparent"
                  >
                    <%= render_slot(cancel) %>
                  </.button>

                  <.button
                    :for={confirm <- @confirm}
                    id={"#{@id}-confirm"}
                    phx-click={@on_confirm}
                    phx-disable-with
                    class="py-2 px-3"
                    variant={:primary}
                  >
                    <%= render_slot(confirm) %>
                  </.button>
                </div>
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :class, :string, default: ""
  attr :body_class, :string, default: "p-6 space-y-6"
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  attr :on_confirm, JS, default: %JS{}

  slot :inner_block, required: true
  slot :title
  slot :subtitle
  slot :confirm
  slot :cancel

  def student_delivery_modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="fixed inset-0 bg-black/20 transition-opacity backdrop-blur-sm"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class={["w-full p-4 sm:p-6 lg:py-8", @class]}>
            <.focus_wrap
              id={"#{@id}-container"}
              phx-mounted={@show && show_modal(@id)}
              phx-window-keydown={hide_modal(@on_cancel, @id)}
              phx-key="escape"
              phx-click-away={hide_modal(@on_cancel, @id)}
              class="hidden p-8 sm:p-16 lg:p-20 xl:p-28 relative bg-white dark:bg-black shadow-lg shadow-zinc-700/10 ring-1 ring-zinc-700/10 transition"
            >
              <button
                type="button"
                class="absolute top-5 right-5 lg:top-10 lg:right-10 dark:text-gray-400 dark:hover:text-white text-gray-900 hover:text-gray-400 text-sm w-8 h-8  flex items-center justify-center"
                phx-click={hide_modal(@on_cancel, @id)}
                aria-label={gettext("close")}
              >
                <svg
                  class="w-3 h-3"
                  aria-hidden="true"
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 14 14"
                >
                  <path
                    stroke="currentColor"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="m1 1 6 6m0 0 6 6M7 7l6-6M7 7l-6 6"
                  />
                </svg>
                <span class="sr-only">Close modal</span>
              </button>
              <!-- Modal header -->
              <div class="flex items-start justify-between">
                <div :if={@title != []} class="mb-11">
                  <h1
                    id={"#{@id}-title"}
                    class="text-zinc-700 dark:text-neutral-300 text-[40px] font-bold font-['Inter'] leading-[60px]"
                  >
                    <%= render_slot(@title) %>
                  </h1>
                  <p
                    :if={@subtitle != []}
                    id={"#{@id}-description"}
                    class="mt-11 text-zinc-700 dark:text-white text-base font-normal font-['Inter'] leading-normal"
                  >
                    <%= render_slot(@subtitle) %>
                  </p>
                </div>
              </div>
              <!-- Modal body -->
              <div class={@body_class}>
                <%= render_slot(@inner_block) %>
              </div>
              <!-- Modal footer -->
              <div :if={@confirm != [] or @cancel != []}>
                <div class="flex justify-end p-6 space-x-2">
                  <.button
                    :for={cancel <- @cancel}
                    phx-click={hide_modal(@on_cancel, @id)}
                    class="bg-transparent text-blue-500 hover:underline hover:bg-transparent"
                  >
                    <%= render_slot(cancel) %>
                  </.button>

                  <.button
                    :for={confirm <- @confirm}
                    id={"#{@id}-confirm"}
                    phx-click={@on_confirm}
                    phx-disable-with
                    class="py-2 px-3"
                    variant={:primary}
                  >
                    <%= render_slot(confirm) %>
                  </.button>
                </div>
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  ## JS Commands

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end
end
