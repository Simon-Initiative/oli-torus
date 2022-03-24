defmodule OliWeb.Common.CardListing do
  use Surface.Component

  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Delivery.SelectSource.TableModel
  alias Surface.Components.Form.{Field, RadioButton}

  prop model, :struct, required: true
  prop sort, :event, required: true
  prop selected, :event, required: true
  prop context, :any

  def render(assigns) do
    ~F"""
    <div class="select-sources d-flex flex-column">
      <form :on-change={@sort} class="d-flex justify-content-end align-items-center mb-3">
        <select name="sort_by" id="select_sort" class="custom-select custom-select-sm mr-2">
          <option value="" disabled selected>Sort by</option>
          {#for column_spec <- @model.column_specs}
            {#if column_spec.name != :action}
              <option value={column_spec.name} selected={@model.sort_by_spec == column_spec}>{column_spec.label}</option>
            {/if}
          {/for}
        </select>
        <Field name="sort_order">
          <div class="control">
            <label class="radio"><RadioButton value="desc" checked={@model.sort_order == :desc}/> Desc</label>
            <label class="radio"><RadioButton value="asc" checked={@model.sort_order == :asc} /> Asc</label>
          </div>
        </Field>
      </form>

      <div class="card-deck pb-5">
        {#for item <- @model.rows}
          <a :on-click={@selected} phx-value-id={action_id(item)}>
            <div class="card mb-4">
              <img src={Routes.static_path(OliWeb.Endpoint, "/images/course_default.jpg")} class="card-img-top" alt="course image">
              <div class="card-body">
                <h5 class="card-title text-primary">{render_title_column(item)}</h5>
                <div class="fade-text"><p class="card-text text-muted small">{item.description}</p></div>
                <div class="d-flex pl-3 pt-3">
                  <div class="text-success mr-5">{TableModel.render_payment_column(assigns, item, nil)}</div>
                  <div class="small-date">{render_date(item, assigns)}</div>
                </div>
              </div>
            </div>
          </a>
        {/for}
      </div>
    </div>
    """
  end

  defp render_title_column(item) do
    if TableModel.is_product?(item),
      do: item.title,
      else:  item.project.title
  end

  defp render_date(item, assigns),
    do: FormatDateTime.date(Map.get(item, :inserted_at), Map.get(assigns, :context))

  defp action_id(item) do
    if TableModel.is_product?(item),
      do: "product:#{item.id}",
      else: "publication:#{item.id}"
  end
end
