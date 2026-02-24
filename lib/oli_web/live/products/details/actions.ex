defmodule OliWeb.Products.Details.Actions do
  use OliWeb, :html
  alias OliWeb.Router.Helpers, as: Routes

  attr(:product, :any, required: true)
  attr(:is_admin, :boolean, required: true)
  attr(:base_project, :map, required: true)
  attr(:has_payment_codes, :boolean, required: true)

  def render(assigns) do
    ~H"""
    <div>
      <div class="d-flex align-items-center">
        <div>
          <button class="btn btn-link action-button" phx-click="request_duplicate">
            Duplicate
          </button>
        </div>
        <div>Create a complete copy of this template.</div>
      </div>

      <div :if={@is_admin} class="d-flex align-items-center">
        <div>
          <a
            class="btn btn-link action-button"
            href={Routes.live_path(OliWeb.Endpoint, OliWeb.Products.PaymentsView, @product.slug)}
          >
            Manage Payments
          </a>
        </div>
        <div>Audit payments and manage payment codes.</div>
      </div>

      <div
        :if={@base_project.allow_transfer_payment_codes && @has_payment_codes}
        class="d-flex align-items-center"
      >
        <div>
          <button class="btn btn-link action-button" phx-click="show_products_to_transfer">
            Transfer Payment Codes
          </button>
        </div>
        <div>Allow transfer of payment codes to another template.</div>
      </div>

      <div class="d-flex align-items-center">
        <div>
          <button class="btn btn-link action-button">
            View Usage
          </button>
        </div>
        <div>View course section usage.</div>

        <div class="badge badge-info">Coming Soon</div>
      </div>
    </div>
    """
  end
end
