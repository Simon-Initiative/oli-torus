defmodule OliWeb.Components.Delivery.Students.EmailButton do
  use OliWeb, :live_component

  alias OliWeb.Components.DesignTokens.Primitives.Button
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  def update(assigns, socket) do
    selected_students =
      Map.get(assigns, :selected_students, socket.assigns[:selected_students] || [])

    previous_selected_students = socket.assigns[:selected_students] || []

    selected_emails =
      if socket.assigns[:selected_emails] && selected_students == previous_selected_students do
        socket.assigns.selected_emails
      else
        load_selected_emails(selected_students)
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:selected_students, selected_students)
     |> assign(:selected_emails, selected_emails)
     |> assign(:variant, normalize_variant(Map.get(assigns, :variant, :full)))}
  end

  def render(assigns) do
    ~H"""
    <div id="email_button_wrapper" class={if(@variant == :full, do: "relative", else: nil)}>
      <%= if @variant == :minimal do %>
        <Button.button
          variant={:secondary}
          size={:sm}
          disabled={length(@selected_students) == 0}
          phx-click="show_email_modal"
          phx-target={@myself}
        >
          <:icon_left>
            <Icons.email class="h-4 w-4 stroke-current" />
          </:icon_left>
          Email Selected
        </Button.button>
      <% else %>
        <Button.button
          variant={:primary}
          size={:sm}
          disabled={length(@selected_students) == 0}
          phx-click={
            if(length(@selected_students) > 0, do: JS.toggle(to: "#email-dropdown-#{@id}"), else: nil)
          }
          phx-target={@myself}
        >
          <:icon_left>
            <Icons.email class="h-4 w-4 stroke-current" />
          </:icon_left>
          Email
          <:icon_right>
            <Icons.chevron_down class="h-4 w-4" />
          </:icon_right>
        </Button.button>

        <div
          id={"email-dropdown-#{@id}"}
          class="absolute right-0 z-50 mt-2 hidden w-48 rounded-md border border-Border-border-subtle bg-Surface-surface-primary shadow-lg"
          phx-click-away={JS.hide(to: "#email-dropdown-#{@id}")}
        >
          <div class="py-1">
            <button
              id={"copy-emails-button-#{@id}"}
              class="w-full px-4 py-2 text-left text-sm text-Text-text-high hover:bg-Surface-surface-secondary-hover"
              phx-hook="CopyToClipboard"
              data-copy-text={@selected_emails}
              phx-click={JS.push("copy_email_addresses") |> JS.hide(to: "#email-dropdown-#{@id}")}
              phx-target={@myself}
            >
              Copy email addresses
            </button>
            <button
              class="w-full px-4 py-2 text-left text-sm text-Text-text-high hover:bg-Surface-surface-secondary-hover"
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
      <% end %>
    </div>
    """
  end

  def handle_event("copy_email_addresses", _params, socket) do
    send(self(), {:flash_message, {:info, "Email addresses copied to clipboard"}})

    {:noreply, socket}
  end

  def handle_event("show_email_modal", _params, socket) do
    send(self(), {:show_email_modal, socket.assigns})
    {:noreply, socket}
  end

  # Reuse the computed email list unless the selected student ids change.
  # Longer term, this lookup should likely move to the parent and be passed
  # into EmailButton as data from the Students page, the Learning Objectives
  # student proficiency list, and the Student Support tile call sites.
  defp load_selected_emails(selected_students) do
    selected_students
    |> Oli.Accounts.get_user_emails_by_ids()
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp normalize_variant(variant) when variant in [:full, "full"], do: :full
  defp normalize_variant(variant) when variant in [:minimal, "minimal"], do: :minimal
  defp normalize_variant(_), do: :full
end
