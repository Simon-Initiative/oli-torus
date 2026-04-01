defmodule OliWeb.Products.Details.Actions do
  use OliWeb, :html
  alias OliWeb.Router.Helpers, as: Routes

  attr(:product, :any, required: true)
  attr(:is_admin, :boolean, required: true)
  attr(:base_project, :map, required: true)
  attr(:has_payment_codes, :boolean, required: true)
  attr(:usage_path, :string, required: true)
  attr(:preview_launching?, :boolean, default: false)
  attr(:preview_url, :string, default: nil)

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-2">
      <div class="flex items-center gap-3">
        <div>
          <a class="btn btn-link action-button" href={@usage_path}>
            View Usage
          </a>
        </div>
        <div>View course section usage.</div>
      </div>

      <div class="flex items-center gap-3">
        <div>
          <button
            class="btn btn-secondary action-button"
            phx-click="request_duplicate"
            type="button"
          >
            Duplicate
          </button>
        </div>
        <div>Create a complete copy of this template.</div>
      </div>

      <div :if={@is_admin} class="flex items-center gap-3">
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
        class="flex items-center gap-3"
      >
        <div>
          <button class="btn btn-link action-button" phx-click="show_products_to_transfer">
            Transfer Payment Codes
          </button>
        </div>
        <div>Allow transfer of payment codes to another template.</div>
      </div>

      <div class="flex flex-col gap-2">
        <div class="flex items-center gap-3">
          <div>
            <button
              class="btn btn-primary action-button inline-flex items-center gap-2"
              phx-click="template_preview"
              type="button"
              disabled={@preview_launching?}
              aria-label="Preview Template"
            >
              <i class="fa-solid fa-eye" aria-hidden="true" />
              <span>
                {if @preview_launching?, do: "Preparing Preview...", else: "Preview Template"}
              </span>
            </button>
          </div>
          <div>Open the student delivery experience for this template in a new tab.</div>
        </div>

        <div :if={@preview_url} class="flex items-center gap-3">
          <div>
            <a class="btn btn-link action-button" href={@preview_url} target="_blank" rel="noopener">
              Open Preview
            </a>
          </div>
          <div>Use this if your browser blocked the automatic preview launch.</div>
        </div>
      </div>
    </div>
    """
  end
end
