defmodule OliWeb.ManualGrading.Apply do
  use OliWeb, :html

  attr(:disabled, :boolean, required: true)
  attr(:apply, :any, required: true)

  def render(assigns) do
    ~H"""
    <div class="flex justify-center">
      <button
        class="inline-flex h-10 items-center justify-center rounded-md bg-Fill-Buttons-fill-primary px-5 text-sm font-semibold text-Text-text-white transition-colors hover:bg-Fill-Buttons-fill-primary-hover disabled:cursor-not-allowed disabled:bg-Icons-Icons-icon-disabled disabled:text-Text-text-disabled"
        disabled={@disabled}
        phx-click={@apply}
      >
        Apply Score and Feedback
      </button>
    </div>
    """
  end
end
