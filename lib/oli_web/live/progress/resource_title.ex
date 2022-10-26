defmodule OliWeb.Progress.ResourceTitle do
  use Surface.Component

  @moduledoc """
  Display the title of a resource, with a breadcrumb-like header above it indicating the
  path within the curriculum to this resource.
  """

  prop node, :any, required: true
  prop url, :string, required: true

  def render(assigns) do
    length = length(assigns.node.ancestors)
    numbering = assigns.node.numbering

    ~F"""
    <div>
      <div>
        <small class="text-muted">
          {#for {ancestor, index} <- Enum.with_index(@node.ancestors)}
            {n = %Oli.Resources.Numbering{numbering | level: ancestor.section_resource.numbering_level, index: ancestor.section_resource.numbering_index}}
            <span>{Oli.Resources.Numbering.container_type_label(n)} {ancestor.section_resource.numbering_index}</span>
            {#if index + 1 < length}
              <span> / </span>
            {/if}
          {/for}
        </small>
      </div>
      <a href={@url}>{@node.revision.title}</a>
    </div>
    """
  end
end
