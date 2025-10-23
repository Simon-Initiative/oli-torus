defmodule OliWeb.Curriculum.Details do
  @moduledoc """
  Curriculum item entry component.
  """

  use OliWeb, :html

  alias OliWeb.Common.Utils

  attr(:child, :map, required: true)
  attr(:ctx, :map, required: true)

  def render(assigns) do
    ~H"""
    <div class="entry-section d-flex flex-column col-span-4">
      <small class="text-muted">
        Created {Utils.render_date(@child.resource, :inserted_at, @ctx)}
      </small>
      <small class="text-muted">
        Updated {Utils.render_date(@child, :updated_at, @ctx)} by {@child.author.name}
      </small>
    </div>
    """
  end
end
