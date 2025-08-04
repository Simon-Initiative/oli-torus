defmodule OliWeb.Qa.WarningSummary do
  use OliWeb, :html
  import OliWeb.Qa.Utils

  attr(:warning, :map, required: true)
  attr(:selected, :map, required: true)

  def render(assigns) do
    ~H"""
    <li
      tabindex="0"
      class={"review-link #{warning_selected?(@warning, @selected)}"}
      phx-click="select"
      phx-value-warning={@warning.id}
      phx-keydown="keydown"
    >
      <span class="review-link-header">
        {warning_icon(@warning.review.type)} {String.capitalize(@warning.subtype)}
      </span>
      <span class="d-flex justify-content-between review-link-subheader">
        {@warning.revision.title}
      </span>
    </li>
    """
  end
end
