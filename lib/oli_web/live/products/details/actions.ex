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
            Manage Payment Codes
          </button>
        </p>
        <span>View existing and create new payment codes</span>
      </div>

    </div>

    """
  end
end
