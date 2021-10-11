defmodule OliWeb.Products.Details.Actions do
  use Surface.Component
  alias OliWeb.Router.Helpers, as: Routes

  prop product, :any, required: true
  prop is_admin, :boolean, required: true

  def render(assigns) do
    ~F"""
    <div>
      <div class="d-flex align-items-center">
        <p>
          <button class="btn btn-link action-button" :on-click="request_duplicate">
            Duplicate
          </button>
        </p>
        <span>Create a complete copy of this product.</span>
      </div>

      {#if @is_admin}

        <div class="d-flex align-items-center">
          <p>
            <a class="btn btn-link action-button" href={Routes.live_path(OliWeb.Endpoint, OliWeb.Products.PaymentsView, @product.slug)}>
              Manage Payments
            </a>
          </p>
          <span>Audit payments and manage payment codes.</span>
        </div>

      {/if}

      <div class="d-flex align-items-center">
        <p>
          <button class="btn btn-link action-button">
            View Usage
          </button>
        </p>
        <span>View course section usage.</span> <span class="badge badge-info">Coming Soon</span>
      </div>
    </div>

    """
  end
end
