defmodule OliWeb.Delivery.Remix.UnsavedChangesModal do
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias OliWeb.Components.Modal
  alias OliWeb.Components.DesignTokens.Primitives.Button

  attr :id, :string, default: "unsaved_changes_modal"
  attr :show, :boolean, default: false

  def render(assigns) do
    ~H"""
    <Modal.modal
      id={@id}
      show={@show}
      show_close={false}
      class="md:w-5/12"
      container_class="rounded-[16px] border border-Border-border-default shadow-[0px_2px_10px_0px_rgba(0,50,99,0.1)] p-6 md:p-16"
      header_class="flex items-start justify-between"
      title_class="text-[24px] font-bold leading-[32px] text-Text-text-high"
      subtitle_class="mt-3 text-[16px] font-medium text-Text-text-medium"
      body_class=""
      on_cancel={JS.push("dismiss_unsaved_changes_modal")}
    >
      <:title>
        <div class="flex items-center gap-3">
          <OliWeb.Icons.warning_triangle class="w-5 h-5 shrink-0 stroke-Icon-icon-accent-orange" />
          <span>Unsaved Changes</span>
        </div>
      </:title>
      <:subtitle>
        You are about to leave this page without saving. All changes will be lost. Are you sure you want to leave without saving?
      </:subtitle>
      <:header_actions>
        <button
          type="button"
          class="absolute top-8 right-8 size-5 flex items-center justify-center text-Icon-icon-default hover:text-Icon-icon-hover"
          phx-click={JS.push("dismiss_unsaved_changes_modal")}
          aria-label="Close"
        >
          <OliWeb.Icons.close_sm class="w-5 h-5 stroke-current" />
        </button>
      </:header_actions>

      <:custom_footer>
        <div class="flex items-stretch justify-end gap-4 mt-10">
          <Button.button
            variant={:secondary}
            size={:sm}
            class="!h-auto !py-2"
            phx-click="unsaved_changes_leave"
          >
            Leave Without Saving
          </Button.button>
          <Button.button
            variant={:primary}
            size={:sm}
            class="!h-auto !py-2"
            phx-click="unsaved_changes_save"
          >
            Save Changes
          </Button.button>
        </div>
      </:custom_footer>
    </Modal.modal>
    """
  end
end
