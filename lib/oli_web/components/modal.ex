defmodule OliWeb.Components.Modal do
  use Phoenix.Component

  use Gettext, backend: OliWeb.Gettext

  import OliWeb.Components.Common

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
  attr :header_class, :string, default: "flex items-start justify-between p-4"
  attr :body_class, :string, default: "p-6 space-y-6"
  attr :confirm_class, :string, default: "py-2 px-3"
  attr :header_level, :integer, default: 1

  attr :cancel_class, :string,
    default: "bg-transparent text-blue-500 hover:underline hover:bg-transparent"

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
      class={["relative z-[2000]", @show && "block", !@show && "hidden"]}
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
              class={[
                "relative bg-white dark:bg-body-dark shadow-lg shadow-zinc-700/10 ring-1 ring-zinc-700/10 transition",
                @show && "block",
                !@show && "hidden"
              ]}
            >
              <!-- Modal header -->
              <div class={@header_class}>
                <div>
                  <div :if={@title != []}>
                    {Phoenix.HTML.Tag.content_tag(
                      :"h#{@header_level}",
                      render_slot(@title),
                      id: "#{@id}-title",
                      class: "text-xl font-semibold text-gray-900 dark:text-white"
                    )}
                    <p
                      :if={@subtitle != []}
                      id={"#{@id}-description"}
                      class="mt-2 text-sm leading-6 text-zinc-600"
                    >
                      {render_slot(@subtitle)}
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
                {render_slot(@inner_block)}
              </div>
              <!-- Modal footer -->
              {render_slot(@custom_footer)}
              <div :if={@confirm != [] or @cancel != []}>
                <div class="flex justify-end p-6 space-x-2">
                  <.button
                    :for={cancel <- @cancel}
                    phx-click={hide_modal(@on_cancel, @id)}
                    class={@cancel_class}
                  >
                    {render_slot(cancel)}
                  </.button>

                  <.button
                    :for={confirm <- @confirm}
                    id={"#{@id}-confirm"}
                    phx-click={@on_confirm}
                    phx-disable-with
                    class={@confirm_class}
                  >
                    {render_slot(confirm)}
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
      class="relative z-[1000] hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="fixed inset-x-0 top-[56px] bottom-0 sm:inset-0 bg-black/20 transition-opacity backdrop-blur-sm"
        aria-hidden="true"
      />
      <div
        class="fixed inset-x-0 top-[56px] bottom-0 sm:inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-start sm:items-center justify-center">
          <div class={["w-full h-full sm:h-auto p-0 sm:p-4 sm:p-6 lg:py-8", @class]}>
            <.focus_wrap
              id={"#{@id}-container"}
              phx-mounted={@show && show_modal(@id)}
              phx-window-keydown={hide_modal(@on_cancel, @id)}
              phx-key="escape"
              phx-click-away={hide_modal(@on_cancel, @id)}
              class="h-full sm:max-h-[85vh] overflow-y-scroll hidden p-0 sm:p-14 lg:p-16 xl:p-20 relative bg-Specially-Tokens-Background-lesson-page shadow-lg shadow-zinc-700/10 ring-1 ring-zinc-700/10 transition"
            >
              <!-- Mobile: Back button in dark header bar -->
              <div class="sm:hidden sticky top-0 z-20 px-4 py-3 bg-Surface-surface-secondary">
                <button
                  type="button"
                  class="text-Text-text-high hover:text-Text-text-low text-sm flex items-center gap-1.5"
                  phx-click={hide_modal(@on_cancel, @id)}
                  aria-label={gettext("close")}
                >
                  <OliWeb.Icons.back_arrow class="w-4 h-4 [&>path]:stroke-current" />
                  <span class="hover:underline">Back</span>
                </button>
              </div>
              
    <!-- Modal header -->
              <div class="flex items-start justify-between px-4 sm:px-0">
                <div :if={@title != []} class="mb-6 lg:mb-11 w-full">
                  <div class="flex items-start justify-between sticky top-0 z-10 pt-8 sm:pt-14 lg:pt-16 xl:pt-20 bg-Specially-Tokens-Background-lesson-page w-full pb-2">
                    <h2
                      id={"#{@id}-title"}
                      class="text-zinc-700 dark:text-neutral-300 text-xl sm:text-3xl lg:text-[40px] font-bold font-['Inter'] leading-normal sm:leading-[60px]"
                    >
                      {render_slot(@title)}
                    </h2>
                    <!-- Desktop: X icon -->
                    <button
                      type="button"
                      class="hidden sm:flex dark:text-gray-400 dark:hover:text-white text-gray-900 hover:text-gray-400 text-sm w-8 h-8 items-center justify-center"
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

                  <p
                    :if={@subtitle != []}
                    id={"#{@id}-description"}
                    class="mt-6 lg:mt-11 text-zinc-700 dark:text-white text-base font-normal font-['Inter'] leading-normal"
                  >
                    {render_slot(@subtitle)}
                  </p>
                </div>
              </div>
              <!-- Modal body -->
              <div class={["px-4 sm:px-0 pb-8", @body_class]}>
                {render_slot(@inner_block)}
              </div>
              <!-- Modal footer -->
              <div :if={@confirm != [] or @cancel != []}>
                <div class="flex justify-end p-6 space-x-2">
                  <.button
                    :for={cancel <- @cancel}
                    phx-click={hide_modal(@on_cancel, @id)}
                    class="bg-transparent text-blue-500 hover:underline hover:bg-transparent"
                  >
                    {render_slot(cancel)}
                  </.button>

                  <.button
                    :for={confirm <- @confirm}
                    id={"#{@id}-confirm"}
                    phx-click={@on_confirm}
                    phx-disable-with
                    class="py-2 px-3"
                    variant={:primary}
                  >
                    {render_slot(confirm)}
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
    |> JS.focus_first(to: "##{id}-container")
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
