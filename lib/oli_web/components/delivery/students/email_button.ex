defmodule OliWeb.Components.Delivery.Students.EmailButton do
  use OliWeb, :live_component

  alias OliWeb.Components.DesignTokens.Primitives.Button
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  def render(assigns) do
    selected_emails =
      assigns.selected_students
      |> Oli.Accounts.get_user_emails_by_ids()
      |> Enum.reject(&is_nil/1)
      |> Enum.join(", ")

    variant = normalize_variant(Map.get(assigns, :variant, :full))

    assigns =
      assigns
      |> assign(:selected_emails, selected_emails)
      |> assign(:variant, variant)

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

  defp normalize_variant(variant) when variant in [:full, "full"], do: :full
  defp normalize_variant(variant) when variant in [:minimal, "minimal"], do: :minimal
  defp normalize_variant(_), do: :full
end
