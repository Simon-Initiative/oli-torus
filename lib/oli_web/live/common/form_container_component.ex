defmodule OliWeb.Common.FormContainerComponent do
  use Surface.Component

  prop title, :string, required: true
  prop bs_row_class, :string, default: "row"
  prop bs_col_class, :string, default: "col-sm-12 col-md-10 col-lg-8 col-xl-6 mx-auto"
  slot default, required: true

  def render(assigns) do
    ~F"""
    <div class="container box-form-container">
      <div class={@bs_row_class}>
        <div class={@bs_col_class}>
          <div class="card signin my-5">
            <div class="card-body">
              <h5 class="card-title text-center">{@title}</h5>
              <#slot />
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
