defmodule OliWeb.Products.Details.Content do
  use Surface.Component
  alias Surface.Components.Link
  alias OliWeb.Router.Helpers, as: Routes

  prop product, :any, required: true
  prop updates, :any, required: true

  def render(assigns) do
    update_count = Enum.count(assigns.updates)

    ~F"""
    <div>
     {#if update_count == 0}
       <p>There are <b>no updates</b> available for this product.</p>
     {#elseif update_count == 1}
       <p>There is <b>one</b> update available for this product.</p>
       <Link
          label={"Manage updates"}
          to={Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.ManageUpdates, @product.slug)}
        />
     {#else}
       <p>There are <b>{update_count}</b> updates available for this product.</p>
       <Link
          label={"Manage updates"}
          to={Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.ManageUpdates, @product.slug)}
        />
     {/if}
      <p>
        <Link
          label={"Customize content"}
          to={Routes.product_remix_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, @product.slug)}
        />
      </p>
      <p>
        <Link
          label={"Gating and scheduling"}
          to={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.GatingAndScheduling, @product.slug)}
        />
      </p>
    </div>

    """
  end
end
