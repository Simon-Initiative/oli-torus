defmodule OliWeb.Products.Details.Content do
  use Surface.Component

  import Ecto.Changeset

  alias OliWeb.Router.Helpers, as: Routes
  alias Surface.Components.{Form, Link}

  alias Surface.Components.Form.{
    Field,
    Label,
    Checkbox
  }

  prop product, :any, required: true
  prop updates, :any, required: true
  prop changeset, :any, default: nil
  prop save, :event, required: true

  def render(assigns) do
    update_count = Enum.count(assigns.updates)

    ~F"""
    <div>
      <div>
        {#if update_count == 0}
          <p>There are <b>no updates</b> available for this product.</p>
        {#elseif update_count == 1}
          <p>There is <b>one</b> update available for this product.</p>
          <Link
              label={"Manage Source Materials"}
              to={Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.ManageSourceMaterials, @product.slug)}
            />
        {#else}
          <p>There are <b>{update_count}</b> updates available for this product.</p>
          <Link
              label={"Manage Source Materials"}
              to={Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.ManageSourceMaterials, @product.slug)}
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

      <div class="grid grid-cols-12 my-4" id="content-form">
        <div class="col-span-12">
          <Form for={@changeset} change={@save} class="d-flex">
            <div class="form-group">
              <div class="form-row">
                <div class="custom-control custom-switch pl-4">
                  <Field name={:display_curriculum_item_numbering} class="form-check">
                    <Checkbox class="custom-control-input" value={get_field(@changeset, :display_curriculum_item_numbering)}/>
                    <Label class="custom-control-label">Display curriculum item numbers</Label>
                    <p class="text-muted">Enable students to see the curriculum's module and unit numbers</p>
                  </Field>
                </div>
              </div>
            </div>
          </Form>
        </div>
      </div>
    </div>
    """
  end
end
