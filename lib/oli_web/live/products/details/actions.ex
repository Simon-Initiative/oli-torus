defmodule OliWeb.Products.Details.Actions do
  use Surface.Component

  prop product, :any, required: true

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

      <div class="d-flex align-items-center">
        <p>
          <button class="btn btn-link action-button">
            Manage Payments
          </button>
        </p>
        <span>Audit payments and manage payment codes.</span> <span class="badge badge-info">Coming Soon</span>
      </div>

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
