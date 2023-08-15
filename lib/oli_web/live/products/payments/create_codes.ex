defmodule OliWeb.Products.Payments.CreateCodes do
  use OliWeb, :html
  alias OliWeb.Router.Helpers, as: Routes
  attr(:product_slug, :string, required: true)
  attr(:count, :integer, required: true)
  attr(:create_codes, :any, required: true)
  attr(:change, :any, required: true)
  attr(:disabled, :boolean, required: true)
  attr(:download_enabled, :boolean, default: false)

  def render(assigns) do
    ~H"""
    <div class="d-flex justify-content-between align-items-center">
      <div class="form-inline">
        <p>Download a new batch of payment codes:</p>
        <input
          class="ml-2 form-control form-control-sm"
          disabled={@disabled}
          type="number"
          value={@count}
          style="width: 90px;"
          phx-blur={@change}
          phx-focus={@change}
        />

        <button class="btn btn-primary btn-sm ml-1" phx-click={@create_codes}>Create</button>
      </div>
      <div>
        <a
          class={"btn btn-outline-primary btn-sm ml-1 fs-button-download" <> if @download_enabled, do: "", else: " disabled"}
          href={route_or_disabled(assigns)}
        >
          Download last created
        </a>
      </div>
    </div>
    """
  end

  defp route_or_disabled(assigns) do
    if assigns.download_enabled do
      Routes.payment_path(
        OliWeb.Endpoint,
        :download_payment_codes,
        assigns.product_slug,
        count: assigns.count
      )
    else
      "#"
    end
  end
end
