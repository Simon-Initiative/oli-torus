defmodule OliWeb.Progress.ResourceTitle do
  use OliWeb, :html

  alias Oli.Delivery.Sections.DisplayLabels
  alias Oli.Resources.Numbering

  @moduledoc """
  Display the title of a resource, with a breadcrumb-like header above it indicating the
  path within the curriculum to this resource.
  """

  attr :node, :any, required: true
  attr :url, :string, required: true

  def render(assigns) do
    length = length(assigns.node.ancestors)
    breadcrumb_segments = Enum.map(assigns.node.ancestors, &ancestor_segment/1)

    assigns = assign(assigns, length: length, breadcrumb_segments: breadcrumb_segments)

    ~H"""
    <div>
      <div>
        <small class="text-muted">
          <%= for {segment, index} <- Enum.with_index(@breadcrumb_segments) do %>
            <span>{segment}</span>
            <%= if index + 1 < @length do %>
              <span> / </span>
            <% end %>
          <% end %>
        </small>
      </div>
      <a href={@url}>{@node.revision.title}</a>
    </div>
    """
  end

  defp ancestor_segment(ancestor) do
    case DisplayLabels.effective_numbering(ancestor) do
      nil -> ancestor.revision.title
      numbering -> Numbering.prefix(numbering)
    end
  end
end
