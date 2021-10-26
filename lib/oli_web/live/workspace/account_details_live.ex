defmodule OliWeb.Workspace.AccountDetailsLive do
  use Surface.LiveView
  use Phoenix.HTML

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Accounts
  alias Oli.Accounts.Author

  def mount(_params, %{"current_author_id" => current_author_id}, socket) do
    author = Accounts.get_author!(current_author_id)

    socket =
      socket
      |> assign(
        title: "Account",
        current_author: author,
        preferences: author.preferences,
        changeset: Author.noauth_changeset(author)
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~F"""
    <div class="container">
      <div class="account-section">
        <div class="row mb-4">
          <div class="col-12">
            <h4 class="mb-3">Name</h4>
            <p class="mb-2">
              {"#{@current_author.name}"}
            </p>
          </div>
        </div>
        <div class="row my-4">
          <div class="col-12">
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
        <div class="row my-4">
          <div class="col-12">
          {link "Change Account Details", to: Routes.authoring_pow_registration_path(OliWeb.Endpoint, :edit), class: "btn btn-outline-primary"}
          </div>
        </div>
      </div>
    </div>
    """
  end

  def providers_for(%Author{} = author) do
    config = OliWeb.Pow.PowHelpers.get_pow_config(:author)

    author
    |> PowAssent.Operations.all(config)
    |> Enum.map(&String.to_existing_atom(&1.provider))
  end
end
