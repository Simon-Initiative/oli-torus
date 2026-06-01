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
          <span>{title(@reason)}</span>
        </div>
      </:title>
      <:subtitle>
        <div class="space-y-3">
          <p>
            You've made changes to your course content structure that haven't been saved yet.
          </p>
          <p>
            To prevent losing your updates, please save your changes before {destination(@reason)}.
          </p>
        </div>
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
        <div class="flex items-stretch justify-between gap-4 mt-10">
          <Button.button
            variant={:secondary}
            size={:sm}
            class="!h-auto !py-2"
            phx-click="dismiss_unsaved_changes_modal"
          >
            Cancel
          </Button.button>
          <Button.button
            variant={:primary}
            size={:sm}
            class="!h-auto !py-2"
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
