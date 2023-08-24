defmodule OliWeb.Progress.AttemptHistory do
  use OliWeb, :html
  alias OliWeb.Progress.PageAttemptSummary

  attr(:resource_attempts, :list, required: true)
  attr(:section, :map, required: true)
  attr(:ctx, :map, required: true)
  attr(:revision, :map, required: true)

  def render(assigns) do
    ~H"""
    <div class="list-group">
      <%= for attempt <- @resource_attempts do %>
        <PageAttemptSummary.render
          revision={@revision}
          attempt={attempt}
          section={@section}
          ctx={@ctx}
        />
      <% end %>
    </div>
    """
  end
end
