defmodule OliWeb.Common.FilterBox do
  use Surface.Component

  alias Surface.Components.Form.{Field, RadioButton}


  @doc "The main filter/search"
  slot default, required: true
  @doc "Extra options that can be added next to search and/or sort"
  slot extra_opts

  prop table_model, :struct, required: true
  prop card_header_text, :string, default: "Select Curriculum"
  prop card_body_text, :string, default: "Select a curriculum source to create your course section."
  prop show_sort, :boolean, default: true
  prop show_more_opts, :boolean, default: true

  def render(assigns) do
    ~F"""
    <div class="card mb-3">
      <h3 class="card-header">{@card_header_text}</h3>
      <div class="card-body">
        <p class="mt-1 mb-4">{@card_body_text}</p>
        <div class="d-flex justify-content-between filter-opts">
          <#slot />

          {#if @show_sort}
            <form :on-change="sort" class="d-flex">
              <select name="sort_by" id="select_sort" class="custom-select custom-select mr-2">
                <option value="" disabled selected>Sort by</option>
                {#for column_spec <- @table_model.column_specs}
                  {#if column_spec.name != :action}
                    <option value={column_spec.name} selected={@table_model.sort_by_spec == column_spec}>{column_spec.label}</option>
                  {/if}
                {/for}
              </select>
              <Field name="sort_order" class="control w-100 d-flex align-items-center">
                <div class="btn-group btn-group-toggle">
                  <label class={"btn btn-outline-secondary" <> if @table_model.sort_order == :desc, do: " active", else: ""}>
                    <RadioButton value="desc" checked={@table_model.sort_order == :desc} opts={hidden: true}/>
                    <i class='fa fa-sort-amount-down'></i>
                  </label>
                  <label class={"btn btn-outline-secondary" <> if @table_model.sort_order == :asc, do: " active", else: ""}>
                    <RadioButton value="asc" checked={@table_model.sort_order == :asc} opts={hidden: true}/>
                    <i class='fa fa-sort-amount-up'></i>
                  </label>
                </div>
              </Field>
            </form>
          {/if}

          {#if @show_more_opts}
            <#slot name="extra_opts"/>
          {/if}
        </div>
      </div>
    </div>
    """
  end
end
