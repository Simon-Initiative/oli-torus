defmodule OliWeb.Progress.ResourceTitle do
  use Surface.Component

  prop node, :any, required: true
  prop url, :string, required: true

  def render(assigns) do
    length = length(assigns.node.ancestors)

    ~F"""
    <div>
      <div>
        <small class="text-muted">
          {#for {ancestor, index} <- Enum.with_index(@node.ancestors)}
            <span>{Oli.Resources.Numbering.container_type(ancestor.section_resource.numbering_level)} {ancestor.section_resource.numbering_index}</span>
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
