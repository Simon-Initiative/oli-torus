defmodule OliWeb.Products.Details.Content do
  use OliWeb, :html

  alias OliWeb.Router.Helpers, as: Routes

  attr(:product, :any, required: true)
  attr(:updates, :any, required: true)
  attr(:changeset, :any, default: nil)
  attr(:save, :any, required: true)

  def render(assigns) do
    ~H"""
    <div>
      <div>
        <p :if={Enum.count(@updates) == 0}>There are <b>no updates</b> available for this product.</p>
        <div :if={Enum.count(@updates) == 1}>
          <p>There is <b>one</b> update available for this product.</p>
          <.link href={
            Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.ManageSourceMaterials, @product.slug)
          }>
            Manage Source Materials
          </.link>
        </div>
        <div :if={Enum.count(@updates) not in [0, 1]}>
          <p>There are <b>{Enum.count(@updates)}</b> updates available for this product.</p>
          <.link href={
            Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.ManageSourceMaterials, @product.slug)
          }>
            Manage Source Materials
          </.link>
        </div>
        <p>
          <.link href={Routes.product_remix_path(OliWeb.Endpoint, :product_remix, @product.slug)}>
            Customize content
          </.link>
        </p>
        <p>
          <.link href={
            Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.GatingAndScheduling, @product.slug)
          }>
            Gating and scheduling
          </.link>
        </p>
      </div>

      <div class="grid grid-cols-12 my-4" id="content-form">
        <div class="col-span-12">
          <.form for={@changeset} phx-change={@save} class="d-flex">
            <div class="form-group">
              <div class="form-row my-3">
                <div class="custom-control custom-switch pl-4">
                  <div class="form-check">
                    <.input
                      type="checkbox"
                      class="custom-control-input"
                      field={@changeset[:display_curriculum_item_numbering]}
                      label="Display curriculum item numbers"
                    />
                    <p class="text-muted">
                      Enable students to see the curriculum's module and unit numbers
                    </p>
                  </div>
                </div>
              </div>
              <div class="form-row my-3">
                <div class="custom-control custom-switch pl-4">
                  <div class="form-check">
                    <.input
                      type="checkbox"
                      class="custom-control-input"
                      field={@changeset[:apply_major_updates]}
                      label="Apply major updates to course sections"
                    />
                    <p class="text-muted">
                      Allow major project publications to be applied to course sections created from this product
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end
