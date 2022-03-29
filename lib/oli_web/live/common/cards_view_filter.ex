defmodule OliWeb.Common.CardsViewFilter do
  use Surface.Component

  alias Surface.Components.Form.{Field, RadioButton}

  slot default, required: true
  prop table_model, :struct, required: true

  def render(assigns) do
    ~F"""
    <div class="card mb-3">
      <h3 class="card-header">Select Curriculum</h3>
      <div class="card-body">
        <p class="mt-1 mb-4">Select a curriculum source to create your course section.</p>

        <div class="d-flex justify-content-between">
          <#slot />

          <form :on-change="sort" class="d-flex">
            <select name="sort_by" id="select_sort" class="custom-select custom-select-sm mr-2 h-100">
              <option value="" disabled selected>Sort by</option>
              {#for column_spec <- @table_model.column_specs}
                {#if column_spec.name != :action}
                  <option value={column_spec.name} selected={@table_model.sort_by_spec == column_spec}>{column_spec.label}</option>
                {/if}
              {/for}
            </select>
            <Field name="sort_order" class="control w-100 d-flex align-items-center">
              <div class="btn-group btn-group-toggle">
                <label class={"btn btn-outline-secondary px-1 py-0" <> if @table_model.sort_order == :desc, do: " active", else: ""}>
                  <RadioButton value="desc" checked={@table_model.sort_order == :desc} opts={hidden: true}/>
                  <i class='fa fa-sort-amount-down fa-2x'></i>
                </label>
                <label class={"btn btn-outline-secondary px-1 py-0" <> if @table_model.sort_order == :asc, do: " active", else: ""}>
                  <RadioButton value="asc" checked={@table_model.sort_order == :asc} opts={hidden: true}/>
                  <i class='fa fa-sort-amount-up fa-2x'></i>
                </label>
              </div>
            </Field>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
