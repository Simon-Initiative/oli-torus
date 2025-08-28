defmodule OliWeb.Components.Delivery.Students.EmailButton do
  use OliWeb, :live_component

  alias OliWeb.Components.Modal
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <div id="email_button_wrapper" class="relative" phx-hook="CopyToClipboardEvent">
      <button
        class={[
          "flex items-center gap-2 px-3 py-2 text-sm font-medium rounded-md",
          if(length(@selected_students) > 0,
            do: "bg-blue-600 text-white hover:bg-blue-700",
            else: "bg-gray-300 text-gray-500 cursor-not-allowed"
          )
        ]}
        disabled={length(@selected_students) == 0}
        phx-click={
          if(length(@selected_students) > 0, do: JS.toggle(to: "#email-dropdown-#{@id}"), else: nil)
        }
        phx-target={@myself}
      >
        <Icons.email class="w-4 h-4" /> Email <Icons.chevron_down class="w-4 h-4" />
      </button>

      <div
        id={"email-dropdown-#{@id}"}
        class="hidden absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg z-50 border border-gray-200"
        phx-click-away={JS.hide(to: "#email-dropdown-#{@id}")}
      >
        <div class="py-1">
          <button
            class="w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
            phx-click={JS.push("copy_email_addresses") |> JS.hide(to: "#email-dropdown-#{@id}")}
            phx-target={@myself}
          >
            Copy email addresses
          </button>
          <button
            class="w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
            phx-click={
              JS.push("show_email_modal")
              |> JS.hide(to: "#email-dropdown-#{@id}")
              |> Modal.show_modal("email_modal")
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
