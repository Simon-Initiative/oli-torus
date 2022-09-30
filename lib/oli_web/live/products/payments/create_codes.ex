defmodule OliWeb.Products.Payments.CreateCodes do
  use Surface.LiveComponent
  alias OliWeb.Router.Helpers, as: Routes
  prop product_slug, :string, required: true
  prop count, :integer, required: true
  prop create_codes, :event, required: true
  prop change, :event, required: true
  prop disabled, :boolean, required: true
  prop download_enabled, :boolean, default: false
  data something, :any, default: true

  def render(assigns) do
    ~F"""
    <div class="d-flex justify-content-between align-items-center">
      <div class="form-inline">

        <p>Download a new batch of payment codes:</p>
        <input class="ml-2 form-control form-control-sm" disabled={@disabled} type="number" value={@count} style="width: 90px;" :on-blur={@change} :on-focus={@change}/>

        <button class="btn btn-primary btn-sm ml-1" :on-click={@create_codes}>Create</button>

      </div>
      <div>
        <a class={"btn btn-outline-primary btn-sm ml-1 fs-button-download" <> if @download_enabled, do: "", else: " disabled"} href={route_or_disabled(assigns)}>Download last created</a>
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
