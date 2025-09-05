defmodule OliWeb.Components.Delivery.Students.EmailButton do
  use OliWeb, :live_component

  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <div id="email_button_wrapper" class="relative" phx-hook="CopyToClipboardEvent">
      <button
        class={[
          "flex items-center gap-2 px-3 py-2 text-sm font-medium rounded-md",
          if(length(@selected_students) > 0,
            do:
              "bg-Fill-Buttons-fill-primary text-Text-text-white hover:bg-Fill-Buttons-fill-primary-hover",
            else: "bg-Fill-Buttons-fill-muted text-Text-text-low-alpha cursor-not-allowed"
          )
        ]}
        disabled={length(@selected_students) == 0}
        phx-click={
          if(length(@selected_students) > 0, do: JS.toggle(to: "#email-dropdown-#{@id}"), else: nil)
        }
        phx-target={@myself}
      >
        <Icons.email class="w-4 h-4 stroke-current" /> Email <Icons.chevron_down class="w-4 h-4" />
      </button>

      <div
        id={"email-dropdown-#{@id}"}
        class="hidden absolute right-0 mt-2 w-48 bg-Surface-surface-primary rounded-md shadow-lg z-50 border border-Border-border-subtle"
        phx-click-away={JS.hide(to: "#email-dropdown-#{@id}")}
      >
        <div class="py-1">
          <button
            class="w-full text-left px-4 py-2 text-sm text-Text-text-high hover:bg-Surface-surface-secondary-hover"
            phx-click={JS.push("copy_email_addresses") |> JS.hide(to: "#email-dropdown-#{@id}")}
            phx-target={@myself}
          >
            Copy email addresses
          </button>
          <button
            class="w-full text-left px-4 py-2 text-sm text-Text-text-high hover:bg-Surface-surface-secondary-hover"
            phx-click={
              JS.push("show_email_modal")
              |> JS.hide(to: "#email-dropdown-#{@id}")
            }
            phx-target={@myself}
          >
            Send email
          </button>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("copy_email_addresses", _params, socket) do
    selected_emails =
      socket.assigns.selected_students
      |> Oli.Accounts.get_user_emails_by_ids()
      |> Enum.reject(&is_nil/1)
      |> Enum.join(", ")

    {:noreply,
     socket
     |> push_event("copy_to_clipboard", %{text: selected_emails})
     |> put_flash(:info, "Email addresses copied to clipboard")}
  end

  def handle_event("show_email_modal", _params, socket) do
    # This would trigger the modal to show
    # For now, we'll just send a message to the parent
    send(self(), {:show_email_modal, socket.assigns})
    {:noreply, socket}
  end
end
