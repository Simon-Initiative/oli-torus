defmodule OliWeb.Workspace.AccountDetailsLive do
  use Surface.LiveView
  use Phoenix.HTML

  alias OliWeb.Router.Helpers, as: Routes
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
    ~F"""
    <Groups>
      <Group label="Details" description="View and change your authoring account details">
        <div class="account-section">
          <div class="grid grid-cols-12 mb-4">
            <div class="col-span-12">
              <h4 class="mb-3">Name</h4>
              <p class="mb-2">
                {"#{@current_author.name}"}
              </p>
            </div>
          </div>
          <div class="grid grid-cols-12 my-4">
            <div class="col-span-12">
              <h4 class="mb-3">Email</h4>
              <p class="mb-2">
                {"#{@current_author.email}"}
              </p>
              {#if Enum.count(providers_for(@current_author)) > 0}
                <h4 class="mt-3">Credentials Managed By</h4>
                {#for provider <- providers_for(@current_author)}
                  <div class="my-2">
                    <span class={"provider provider-#{OliWeb.Pow.PowHelpers.provider_class(provider)}"}>
                    {OliWeb.Pow.PowHelpers.provider_icon(provider)} {OliWeb.Pow.PowHelpers.provider_name(provider)}
                    </span>
                  </div>
                {/for}
              {/if}
            </div>
          </div>
          <div class="grid grid-cols-12 my-4">
            <div class="col-span-12">
            {link "Change Account Details", to: Routes.authoring_pow_registration_path(OliWeb.Endpoint, :edit), class: "btn btn-outline-primary"}
            </div>
          </div>
        </div>
      </Group>
      <Group label="Preferences" description="Adjust your authoring preferences">
        {render_preferences(assigns)}

        <div class="my-4">
          <div class="mb-1">Dark Mode</div>
          <div id="theme-toggle" phx-hook="ThemeToggle" phx-update="ignore"></div>
        </div>
      </Group>
    </Groups>
    """
  end

  defp render_preferences(%{current_author: current_author} = assigns) do
    show_relative_dates = Accounts.get_author_preference(current_author, :show_relative_dates)

    ~F"""
    <div>
      <div class="form-check mt-2">
        <input type="checkbox" id="show_relative_dates" class="form-check-input" checked={show_relative_dates} phx-hook="CheckboxListener" />
        <label for="show_relative_dates" class="form-check-label">Show dates formatted as relative to today</label>
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

  defp providers_for(%Author{} = author) do
    config = OliWeb.Pow.PowHelpers.get_pow_config(:author)

    author
    |> PowAssent.Operations.all(config)
    |> Enum.map(&String.to_existing_atom(&1.provider))
  end
end
