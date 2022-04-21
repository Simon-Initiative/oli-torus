defmodule OliWeb.Common.CardListing do
  use Surface.Component

  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Delivery.SelectSource.TableModel

  prop model, :struct, required: true
  prop selected, :event, required: true
  prop context, :any

  def render(assigns) do
    ~F"""
    <div class="select-sources">
      <div class="card-deck mr-0 ml-0">
        {#for item <- @model.rows}
          <a :on-click={@selected} phx-value-id={action_id(item)}>
            <div class="card mb-2 mr-1 ml-1">
              <img src={Routes.static_path(OliWeb.Endpoint, "/images/course_default.jpg")} class="card-img-top" alt="course image">
              <div class="card-body">
                <h5 class="card-title text-primary">{render_title_column(item)}</h5>
                <div class="fade-text"><p class="card-text small">{render_description(item)}</p></div>
                <div class="d-flex justify-content-between align-items-center pt-2">
                  <div class="badge badge-success mr-5">{TableModel.render_payment_column(assigns, item, nil)}</div>
                  <div class="small-date text-muted">{render_date(item, @context)}</div>
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

  defp render_description(item) do
    if TableModel.is_product?(item),
      do: item.description,
      else:  item.project.description
  end

  defp render_date(item, context),
    do: FormatDateTime.date(Map.get(item, :inserted_at), context)

  defp action_id(item) do
    if TableModel.is_product?(item),
      do: "product:#{item.id}",
      else: "publication:#{item.id}"
  end
end
