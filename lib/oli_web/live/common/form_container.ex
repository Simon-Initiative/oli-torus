defmodule OliWeb.Common.FormContainer do
  use OliWeb, :html

  attr :title, :string, required: true
  attr :bs_row_class, :string, default: "grid grid-cols-12"

  attr :bs_col_class, :string, default: "col-span-12 mx-auto"

  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
    <div class="container box-form-container">
      <div class={@bs_row_class}>
        <div class={@bs_col_class}>
          <div class="card signin my-5">
            <div class="card-body">
              <h5 class="card-title text-center">{@title}</h5>
              {render_slot(@inner_block)}
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
