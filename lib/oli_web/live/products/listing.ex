defmodule OliWeb.Products.Listing do
  use Surface.LiveComponent

  alias OliWeb.Common.Paging
  alias Surface.Components.Link
  alias OliWeb.Router.Helpers, as: Routes

  prop products, :list, required: true
  prop total_count, :integer, required: true
  prop offset, :integer, required: true
  prop limit, :integer, required: true
  prop page_change, :event, required: true

  def render(assigns) do
    ~F"""
    <div>
      {#if @total_count > 0}
        <Paging id="header_paging" total_count={@total_count} offset={@offset} limit={@limit} click={@page_change}/>

        <table class="table table-striped table-bordered">
          <thead>
            <tr>
              <th>Product Title</th><th>Status</th><th>Required Payment</th><th>Base Project</th><th>Created</th>
            </tr>
          </thead>
          <tbody>
          {#for product <- Enum.slice(@products, @offset, @limit)}
            <tr>
              <td>
                <Link
                  label={product.title}
                  to={Routes.live_path(@socket, OliWeb.Products.DetailsView, product.slug)}
                />
              </td>
              <td>{product.status}</td>
              <td>{
                if product.requires_payment do
                  case Money.to_string(product.amount) do
                    {:ok, m} -> m
                    _ -> "Yes"
                  end
                else
                  "None"
                end
              }
              </td>
              <td>
                <Link
                  label={product.base_project.title}
                  to={Routes.project_path(@socket, :overview, product.base_project.slug)}
                />
              </td>
              <td>
                {Timex.format!(product.inserted_at, "{relative}", :relative)}
              </td>
            </tr>
          {/for}
          </tbody>
        </table>

        <Paging id="footer_paging" total_count={@total_count} offset={@offset} limit={@limit} click={@page_change}/>
      {#else}
        <p>No products exist</p>
      {/if}
      </div>
    """
  end
end
