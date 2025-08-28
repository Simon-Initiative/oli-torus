defmodule OliWeb.Common.CardListing do
  use Phoenix.Component

  import OliWeb.Common.SourceImage

  alias OliWeb.Common.Utils
  alias OliWeb.Delivery.NewCourse.TableModel

  attr :model, :map, required: true
  attr :selected, :any, required: true
  attr :ctx, :map, required: true

  def render(assigns) do
    ~H"""
    <div class="select-sources flex justify-center">
      <div class="card-deck mr-0 ml-0 inline-flex flex-wrap justify-center">
        <%= for item <- @model.rows do %>
          <a
            phx-click={@selected}
            class="course-card-link mb-2 no-underline hover:no-underline"
            phx-value-id={action_id(item)}
          >
            <div class={"card mb-2 mr-1 ml-1 h-100 " <> if Map.get(item, :selected), do: "!bg-delivery-primary-100 shadow-inner !border-none", else: ""}>
              <img src={cover_image(item)} class="card-img-top" alt="course image" />
              <div class="card-body">
                <h5 class="card-title mb-1 !whitespace-normal" title={render_title_column(item)}>
                  {render_title_column(item)}
                </h5>
                <div class="fade-text">
                  <p class="card-text text-sm">{render_description(item)}</p>
                </div>
              </div>
              <div class="card-footer bg-transparent d-flex justify-content-between align-items-center border-0">
                <div class="badge badge-success mr-5">
                  {TableModel.render_payment_column(%{}, item, nil)}
                </div>
                <div class="small-date text-muted">
                  {render_date(item, @ctx)}
                </div>
              </div>
            </div>
          </a>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_title_column(item) do
    if TableModel.is_product?(item),
      do: item.title,
      else: item.project.title
  end

  defp render_description(item) do
    if TableModel.is_product?(item),
      do: item.description,
      else: item.project.description
  end

  defp render_date(item, ctx) do
    Utils.render_date(item, :inserted_at, ctx)
  end

  defp action_id(item) do
    if TableModel.is_product?(item),
      do: "product:#{item.id}",
      else: "publication:#{item.id}"
  end
end
