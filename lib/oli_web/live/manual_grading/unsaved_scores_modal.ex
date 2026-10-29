defmodule OliWeb.ManualGrading.UnsavedScoresModal do
  @moduledoc "Asks the instructor to stay or discard unapplied scores before leaving a submission."
  use OliWeb, :html

  alias OliWeb.Components.DesignTokens.Primitives.Button
  alias OliWeb.Components.Modal
  alias Phoenix.LiveView.JS

  attr :id, :string, default: "unsaved-modal"

  def render(assigns) do
    ~H"""
    <Modal.modal
      id={@id}
      show={true}
      show_close={false}
      class="w-full max-w-[640px]"
      wrapper_class="w-full p-4"
      container_class="overflow-hidden rounded-[16px] border border-Border-border-default bg-Surface-surface-background shadow-[0px_2px_10px_0px_rgba(0,50,99,0.1)]"
      header_class="flex min-h-[68px] items-start justify-between border-b border-Border-border-subtle px-7 py-[18px]"
      title_class="text-[24px] font-bold leading-[32px] text-Text-text-high"
      body_class="px-[34px] py-[29px] text-[16px] font-medium leading-9 text-Text-text-high"
      on_cancel={JS.push("dismiss_unsaved_changes_modal")}
    >
      <:title>
        <span class="block px-2 py-1">Unapplied scores or feedback</span>
      </:title>

      <p>You have unapplied scores or feedback for this submission.</p>

      <:custom_footer>
        <div class="flex min-h-[88px] items-start justify-end gap-[10px] border-t border-Border-border-default px-7 py-[23px]">
          <Button.button
            id="modal-stay"
            variant={:secondary}
            size={:sm}
            phx-click="dismiss_unsaved_changes_modal"
          >
            Stay
          </Button.button>
          <Button.button
            id="modal-discard"
            variant={:primary}
            size={:sm}
            phx-click="discard_and_leave"
          >
            Discard and leave
          </Button.button>
        </div>
      </:custom_footer>
    </Modal.modal>
    """
  end
end
