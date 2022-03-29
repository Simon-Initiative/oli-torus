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
      <div class="card-deck pb-5 mr-0 ml-0">
        {#for item <- @model.rows}
          <a :on-click={@selected} phx-value-id={action_id(item)}>
            <div class="card mb-2 mr-1 ml-1">
              <img src={Routes.static_path(OliWeb.Endpoint, "/images/course_default.jpg")} class="card-img-top" alt="course image">
              <div class="card-body">
                <h5 class="card-title text-primary">{render_title_column(item)}</h5>
                <div class="fade-text"><p class="card-text small">{item.description}</p></div>
                <div class="d-flex justify-content-between align-items-center pt-3">
                  <div class="badge badge-success mr-5">{TableModel.render_payment_column(assigns, item, nil)}</div>
                  <div class="small-date text-muted">{render_date(item, assigns)}</div>
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
