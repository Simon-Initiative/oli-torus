defmodule OliWeb.Products.Details.Actions do
  use Surface.Component
  alias OliWeb.Router.Helpers, as: Routes

  prop product, :any, required: true
  prop is_admin, :boolean, required: true

  def render(assigns) do
    ~F"""
    <div>
      <div class="d-flex align-items-center">
        <div>
          <button class="btn btn-link action-button" :on-click="request_duplicate">
            Duplicate
          </button>
        </div>
        <div>Create a complete copy of this product.</div>
      </div>

      {#if @is_admin}

        <div class="d-flex align-items-center">
          <div>
            <a class="btn btn-link action-button" href={Routes.live_path(OliWeb.Endpoint, OliWeb.Products.PaymentsView, @product.slug)}>
              Manage Payments
            </a>
          </div>
          <div>Audit payments and manage payment codes.</div>
        </div>

      {/if}

      <div class="d-flex align-items-center">
        <div>
          <button class="btn btn-link action-button">
            View Usage
          </button>
        </div>
        <div>View course section usage.</div> <div class="badge badge-info">Coming Soon</div>
      </div>
    </div>

    """
  end
end
