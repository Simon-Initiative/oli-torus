defmodule OliWeb.Workspaces.AccountDetailsLive do
  use OliWeb, :live_view

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias OliWeb.Common.Properties.{Groups, Group}

  def mount(_params, %{"current_author_id" => current_author_id}, socket) do
    author = Accounts.get_author!(current_author_id)

    socket =
      socket
      |> assign(
        title: "Account",
        current_author: author,
        changeset: Author.noauth_changeset(author)
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Groups.render>
      <Group.render label="Details" description="View and change your authoring account details">
        <div class="account-section">
          <div class="grid grid-cols-12 mb-4">
            <div class="col-span-12">
              <h4 class="mb-3">Name</h4>
              <p class="mb-2">
                <%= "#{@current_author.name}" %>
              </p>
            </div>
          </div>
          <div class="grid grid-cols-12 my-4">
            <div class="col-span-12">
              <h4 class="mb-3">Email</h4>
              <p class="mb-2">
                <%= "#{@current_author.email}" %>
              </p>
              <%= if Enum.count(providers_for(@current_author)) > 0 do %>
                <h4 class="mt-3">Credentials Managed By</h4>
                <div :for={provider <- providers_for(@current_author)} class="my-2">
                  <%
                    # MER-3835 TODO
                  %>
                </div>
              <% end %>
            </div>
          </div>
          <div class="grid grid-cols-12 my-4">
            <div class="col-span-12">
              <%= link("Change Account Details",
                to: ~p"/authors/settings",
                class: "btn btn-outline-primary"
              ) %>
            </div>
          </div>
        </div>
      </Group.render>
      <Group.render label="Preferences" description="Adjust your authoring preferences">
        <%= render_preferences(assigns) %>

        <div class="my-8">
          <div class="mb-1">Dark Mode</div>
          <div id="theme-toggle" phx-hook="ThemeToggle" phx-update="ignore"></div>
        </div>
      </Group.render>
    </Groups.render>
    """
  end

  defp render_preferences(%{current_author: current_author} = assigns) do
    editor = Accounts.get_author_preference(current_author, :editor)
    show_relative_dates = Accounts.get_author_preference(current_author, :show_relative_dates)

    assigns = assign(assigns, show_relative_dates: show_relative_dates, editor: editor)

    ~H"""
    <div>
      <div class="form-check mt-2">
        <input
          type="checkbox"
          id="show_relative_dates"
          class="form-check-input"
          checked={@show_relative_dates}
          phx-hook="CheckboxListener"
        />
        <label for="show_relative_dates" class="form-check-label">
          Show dates formatted as relative to today
        </label>
      </div>

      <div class="form-check mt-8">
        <label for="editor_selector" class="form-select-label block mb-1">
          Default editor
        </label>
        <select name="editor" id="editor" class="form-select" phx-hook="SelectListener">
          <option value="markdown" selected={@editor == "markdown"}>Markdown</option>
          <option value="slate" selected={@editor == "slate"}>Rich text editor</option>
        </select>
      </div>
    </div>
    """
  end

  def handle_event("change", %{"id" => "show_relative_dates", "checked" => checked}, socket) do
    %{current_author: current_author} = socket.assigns

    {:ok, updated_author} =
      Accounts.set_author_preference(current_author.id, :show_relative_dates, checked)

    {:noreply, assign(socket, current_author: updated_author)}
  end

  def handle_event("change", %{"id" => "editor", "value" => value}, socket) do
    %{current_author: current_author} = socket.assigns

    {:ok, updated_author} = Accounts.set_author_preference(current_author.id, :editor, value)

    {:noreply, assign(socket, current_author: updated_author)}
  end

  defp providers_for(%Author{} = author) do
    # MER-3835 TODO
    throw "NOT IMPLEMENTED"
  end
end
