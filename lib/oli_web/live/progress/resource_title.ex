defmodule OliWeb.Progress.ResourceTitle do
  use OliWeb, :html

  @moduledoc """
  Display the title of a resource, with a breadcrumb-like header above it indicating the
  path within the curriculum to this resource.
  """

  attr :node, :any, required: true
  attr :url, :string, required: true

  def render(assigns) do
    length = length(assigns.node.ancestors)
    numbering = assigns.node.numbering

    assigns = assign(assigns, length: length, numbering: numbering)

    ~H"""
    <div>
      <div>
        <small class="text-muted">
          <%= for {ancestor, index} <- Enum.with_index(@node.ancestors) do %>
            <span>
              {Oli.Resources.Numbering.container_type_label(%Oli.Resources.Numbering{
                @numbering
                | level: ancestor.section_resource.numbering_level,
                  index: ancestor.section_resource.numbering_index
              })} {ancestor.section_resource.numbering_index}
            </span>
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
end
