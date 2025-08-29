defmodule OliWeb.Projects.MCPTokenManager do
  use Phoenix.LiveComponent
  use OliWeb, :verified_routes

  import OliWeb.Components.Common

  alias Oli.MCP.Auth
  alias Oli.MCP.Auth.BearerToken
  alias OliWeb.Components.Modal
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    token = Auth.get_token_by_author_and_project(assigns.current_author.id, assigns.project.id)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:token, token)
     |> assign(:new_token_string, nil)
     |> assign(:changeset, Auth.change_token(token || %BearerToken{}))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="mcp-token-manager" class="mcp-token-manager">
      <%= if @token do %>
        <div class="space-y-4">
          <div class="flex items-center justify-between p-4 border rounded-lg bg-gray-50">
            <div class="flex-1">
              <div class="flex items-center gap-4">
                <div>
                  <p class="font-medium text-gray-900">Bearer Token</p>
                  <p class="text-sm text-gray-600 mt-1">
                    <%= if @token.hint do %>
                      Description: {@token.hint}
                    <% else %>
                      No description provided
                    <% end %>
                  </p>
                  <p class="text-sm text-gray-500 mt-2">
                    Status:
                    <span class={[
                      "font-medium",
                      if(@token.status == :active, do: "text-green-600", else: "text-red-600")
                    ]}>
                      {String.capitalize(to_string(@token.status))}
                    </span>
                  </p>
                  <%= if @token.last_used_at do %>
                    <p class="text-sm text-gray-500 mt-1">
                      Last used: {format_datetime(@token.last_used_at)}
                    </p>
                  <% else %>
                    <p class="text-sm text-gray-500 mt-1">
                      Never used
                    </p>
                  <% end %>
                </div>
              </div>
            </div>
            <div class="flex gap-2">
              <%= if @token.status == :active do %>
                <button
                  type="button"
                  class="torus-button primary"
                  phx-click={Modal.show_modal("regenerate-token-modal")}
                >
                  Regenerate Token
                </button>
              <% else %>
                <div class="flex items-center space-x-3">
                  <span class="text-sm text-red-600 font-medium">
                    Token has been disabled by an administrator
                  </span>
                  <button
                    type="button"
                    class="torus-button primary"
                    disabled
                    title="Cannot regenerate a disabled token"
                  >
                    Regenerate Token
                  </button>
                </div>
              <% end %>
            </div>
          </div>

          <div class="p-4 bg-blue-50 border border-blue-200 rounded-lg">
            <p class="text-sm text-blue-800">
              <strong>Note:</strong>
              Bearer tokens grant read/write access to this project's content via the MCP API.
              Keep your token secure and regenerate it if you suspect it has been compromised.
            </p>
          </div>
        </div>
      <% else %>
        <div class="text-center py-8">
          <Icons.lock class="mx-auto h-12 w-12 text-gray-400" />
          <h3 class="mt-2 text-sm font-medium text-gray-900">No Bearer Token</h3>
          <p class="mt-1 text-sm text-gray-500">
            Generate a Bearer token to allow AI agents to access this project via MCP.
          </p>
          <div class="mt-6">
            <button
              type="button"
              class="torus-button primary"
              phx-click={Modal.show_modal("generate-token-modal")}
            >
              Generate Bearer Token
            </button>
          </div>
        </div>
      <% end %>
      
    <!-- Generate Token Modal -->
      <Modal.modal id="generate-token-modal">
        <:title>Generate MCP Bearer Token</:title>
        <:subtitle>
          Create a new Bearer token for external AI agents to access this project's content.
        </:subtitle>

        <.form
          :let={f}
          for={@changeset}
          phx-submit="generate_token"
          phx-target={@myself}
          id="generate-token-form"
        >
          <div class="form-group">
            <label for="token-hint" class="form-label">
              Description (optional)
            </label>
            <.input
              field={f[:hint]}
              type="text"
              class="form-control"
              placeholder="e.g., Claude Desktop, VS Code Copilot"
              maxlength="255"
            />
            <p class="text-sm text-gray-500 mt-1">
              A brief description to help you identify this token's purpose.
            </p>
          </div>
        </.form>

        <:confirm>
          <button type="submit" form="generate-token-form" phx-disable-with="Generating...">
            Generate Token
          </button>
        </:confirm>
        <:cancel>Cancel</:cancel>
      </Modal.modal>
      
    <!-- Regenerate Token Modal -->
      <Modal.modal id="regenerate-token-modal">
        <:title>Regenerate Bearer Token</:title>
        <:subtitle>
          This will invalidate the existing token and generate a new one.
        </:subtitle>

        <div class="p-4 bg-yellow-50 border border-yellow-200 rounded-lg mb-4">
          <p class="text-sm text-yellow-800">
            <strong>Warning:</strong> Any applications using the current token will lose access.
            You will need to update them with the new token.
          </p>
        </div>

        <.form
          :let={f}
          for={@changeset}
          phx-submit="regenerate_token"
          phx-target={@myself}
          id="regenerate-token-form"
        >
          <div class="form-group">
            <label for="token-hint" class="form-label">
              Description (optional)
            </label>
            <.input
              field={f[:hint]}
              type="text"
              class="form-control"
              placeholder="e.g., Claude Desktop, VS Code Copilot"
              value={@token && @token.hint}
              maxlength="255"
            />
          </div>
        </.form>

        <:confirm>
          <button type="submit" form="regenerate-token-form" phx-disable-with="Regenerating...">
            Regenerate Token
          </button>
        </:confirm>
        <:cancel>Cancel</:cancel>
      </Modal.modal>
      
    <!-- Token Display Modal -->
      <%= if @new_token_string do %>
        <Modal.modal id="token-display-modal" show={true}>
          <:title>Your MCP Bearer Token</:title>
          <:subtitle>
            Copy this token now. You won't be able to see it again.
          </:subtitle>

          <div class="space-y-4">
            <div class="p-4 bg-red-50 border border-red-200 rounded-lg">
              <p class="text-sm text-red-800">
                <strong>Important:</strong> This is the only time you'll see this token.
                Copy it now and store it securely.
              </p>
            </div>

            <div class="relative">
              <div class="p-3 bg-gray-100 rounded-lg font-mono text-sm break-all">
                <span id="token-value">{@new_token_string}</span>
              </div>
              <button
                type="button"
                class="absolute top-2 right-2 p-2 bg-white rounded hover:bg-gray-50"
                phx-hook="CopyToClipboard"
                data-copy-text={@new_token_string}
                id="copy-token-button"
                data-tooltip="Copy to clipboard"
              >
                <Icons.clipboard />
              </button>
            </div>

            <div class="p-4 bg-blue-50 border border-blue-200 rounded-lg">
              <h4 class="font-medium text-blue-900 mb-2">How to use this token:</h4>
              <p class="text-sm text-blue-800 mb-2">
                Add this token to your AI agent's configuration to enable MCP access.
              </p>
              <p class="text-sm text-blue-800">
                Example Authorization header:
                <code class="bg-blue-100 px-1">
                  Bearer {String.slice(@new_token_string, 0, 20)}...
                </code>
              </p>
            </div>
          </div>

          <:custom_footer>
            <button
              type="button"
              class="torus-button primary w-full"
              phx-click={
                JS.push("close_token_display", target: @myself)
                |> Modal.hide_modal("token-display-modal")
              }
            >
              I've copied the token
            </button>
          </:custom_footer>
        </Modal.modal>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("generate_token", %{"bearer_token" => params}, socket) do
    hint = Map.get(params, "hint")

    case Auth.create_token(socket.assigns.current_author.id, socket.assigns.project.id, hint) do
      {:ok, {token, token_string}} ->
        {:noreply,
         socket
         |> assign(:token, token)
         |> assign(:new_token_string, token_string)
         |> push_event("hide-modal", %{id: "generate-token-modal"})}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to generate token. Please try again.")}
    end
  end

  @impl true
  def handle_event("regenerate_token", %{"bearer_token" => params}, socket) do
    hint = Map.get(params, "hint")

    case Auth.regenerate_token(
           socket.assigns.current_author.id,
           socket.assigns.project.id,
           hint
         ) do
      {:ok, {token, token_string}} ->
        {:noreply,
         socket
         |> assign(:token, token)
         |> assign(:new_token_string, token_string)
         |> push_event("hide-modal", %{id: "regenerate-token-modal"})}

      {:error, :token_disabled} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Cannot regenerate a disabled token. Please enable the token first."
         )}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to regenerate token. Please try again.")}
    end
  end

  @impl true
  def handle_event("close_token_display", _params, socket) do
    {:noreply, assign(socket, :new_token_string, nil)}
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p UTC")
  end
end
