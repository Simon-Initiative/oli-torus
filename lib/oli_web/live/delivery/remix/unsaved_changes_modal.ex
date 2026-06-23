defmodule OliWeb.Delivery.Remix.UnsavedChangesModal do
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias OliWeb.Components.Modal
  alias OliWeb.Components.DesignTokens.Primitives.Button

  attr :id, :string, default: "unsaved_changes_modal"
  attr :show, :boolean, default: false
  attr :reason, :atom, default: :navigation

  def render(assigns) do
    ~H"""
    <Modal.modal
      id={@id}
      show={@show}
      show_close={false}
      class="w-full max-w-[916px]"
      wrapper_class="w-full p-4"
      container_class="overflow-hidden rounded-[16px] border border-Border-border-default bg-Surface-surface-background shadow-[0px_2px_10px_0px_rgba(0,50,99,0.1)]"
      header_class="flex min-h-[68px] items-start justify-between border-b border-Border-border-subtle px-7 py-[18px]"
      title_class="text-[24px] font-bold leading-[32px] text-Text-text-high"
      body_class="px-[34px] py-[29px] text-[16px] font-medium leading-9 text-Text-text-high"
      on_cancel={JS.push("dismiss_unsaved_changes_modal")}
    >
      <:title>
        <span class="block px-2 py-1">{title(@reason)}</span>
      </:title>
      <:header_actions>
        <button
          type="button"
          class="flex size-10 items-center justify-center text-Icon-icon-default hover:text-Icon-icon-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
          phx-click={JS.push("dismiss_unsaved_changes_modal")}
          aria-label="Close"
        >
          <OliWeb.Icons.close_sm class="w-5 h-5 stroke-current" />
        </button>
      </:header_actions>

      <div>
        <p>
          You've made changes to your course structure that haven't been saved yet.
        </p>
        <p>
          To prevent losing your updates, please save your changes before {destination(@reason)}.
        </p>
      </div>

      <:custom_footer>
        <div class="flex min-h-[88px] items-start justify-end gap-[10px] border-t border-Border-border-default px-7 py-[23px] sm:px-[78px]">
          <Button.button
            variant={:secondary}
            size={:sm}
            phx-click="dismiss_unsaved_changes_modal"
          >
            Cancel
          </Button.button>
          <Button.button
            variant={:primary}
            size={:sm}
            phx-click={Modal.hide_modal(@id) |> JS.push("unsaved_changes_save")}
          >
            Save and continue
          </Button.button>
        </div>
      </:custom_footer>
    </Modal.modal>
    """
  end

  defp title(:instructor_view), do: "Save your changes before editing"
  defp title(_reason), do: "Save your changes before continuing"

  defp destination(:instructor_view), do: "navigating to instructor view"
  defp destination(_reason), do: "leaving this page"
end
