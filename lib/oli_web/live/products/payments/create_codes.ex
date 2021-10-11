defmodule OliWeb.Products.Payments.CreateCodes do
  use Surface.LiveComponent
  alias OliWeb.Router.Helpers, as: Routes
  prop product_slug, :string, required: true
  prop count, :integer, required: true
  prop click, :event, required: true
  prop change, :event, required: true

  data something, :any, default: true

  def render(assigns) do
    ~F"""
    <div>
      <div class="form-inline">

        <p>Download a new batch of payment codes:</p>
        <input class="ml-2 form-control form-control-sm" type="number" value={@count} style="width: 90px;" :on-blur={@change} :on-keyup={@change}/>

        <a class="btn btn-primary btn-sm ml-1" href={Routes.payment_path(OliWeb.Endpoint, :download_codes, @product_slug, @count)} >Create</a>

      </div>
      <div>
        <small class="text-muted">You will need to refresh this page to see these newly created codes</small>
      </div>
    </div>
    """
  end
end
