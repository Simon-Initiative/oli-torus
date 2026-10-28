defmodule OliWeb.Workspaces.CourseAuthor.Objectives.Actions do
  use Phoenix.Component

  attr :slug, :string, required: true

  def actions(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <button
        type="button"
        phx-click="display_add_existing_sub_modal"
        phx-value-slug={@slug}
        class={button_class()}
      >
        Add Existing
      </button>
      <button
        type="button"
        phx-click="display_new_sub_modal"
        phx-value-slug={@slug}
        class={button_class()}
      >
        Create New
      </button>
    </div>
    """
  end

  defp button_class do
    "inline-flex min-h-8 items-center justify-center rounded-md border border-Border-border-bold bg-Surface-surface-background px-6 py-2 text-sm font-semibold leading-4 text-Specially-Tokens-Text-text-button-secondary shadow-[0px_2px_4px_rgba(0,52,99,0.10)] transition hover:bg-Surface-surface-secondary-hover hover:text-Specially-Tokens-Text-text-button-secondary-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
  end
end
