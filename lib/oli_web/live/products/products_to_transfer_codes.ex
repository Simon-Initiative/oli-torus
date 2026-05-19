defmodule OliWeb.Products.ProductsToTransferCodes do
  use OliWeb, :html

  attr(:id, :string, required: true)
  attr(:products_to_transfer, :any, required: true)
  attr(:changeset, :any, required: true)

  def render(assigns) do
    ~H"""
    <div
      class="modal fade fixed top-0 left-0 hidden w-full h-full outline-none overflow-x-hidden overflow-y-auto"
      id={@id}
      tabindex="-1"
      aria-labelledby="exampleModalLgLabel"
      aria-modal="true"
      role="dialog"
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog modal-dialog-centered modal-md relative w-auto pointer-events-none">
        <div class="modal-content border-none shadow-lg relative flex flex-col w-full pointer-events-auto bg-white bg-clip-padding rounded-md outline-none">
          <div class="modal-header flex flex-shrink-0 items-center justify-between p-4 border-b border-gray-200 rounded-t-md">
            <h5 class="text-xl font-medium leading-normal" id="exampleModalLgLabel">
              Transfer Payment Codes
            </h5>
            <button
              type="button"
              class="btn-close box-content p-1 border-none rounded-none opacity-50 focus:shadow-none focus:outline-none focus:opacity-100 hover:opacity-75 hover:no-underline"
              data-bs-dismiss="modal"
              aria-label="Close"
            >
              <i class="fa-solid fa-xmark fa-xl"></i>
            </button>
          </div>

          <.form for={@changeset} phx-submit="submit_transfer_payment_codes">
            <div class="modal-body relative px-4 py-8 flex flex-col gap-y-4">
              <%= if @products_to_transfer not in [nil, []] do %>
                <h6>Select a template to transfer payment codes from this template.</h6>

                <div class="flex flex-row gap-x-2 items-center">
                  <.input
                    id="product"
                    class="torus-select"
                    aria-describedby="select_product"
                    type="select"
                    placeholder="Select a template"
                    name="product_id"
                    value={fetch_field(@changeset, :id)}
                    options={Enum.map(@products_to_transfer, &{&1.title, &1.id})}
                  />
                </div>
              <% else %>
                <h6>There are no templates available to transfer payment codes.</h6>
              <% end %>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
              <button type="submit" class="btn btn-success">
                Confirm
              </button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end
