defmodule OliWeb.Progress.AttemptHistory do
  use Surface.Component
  alias OliWeb.Progress.PageAttemptSummary

  prop resource_attempts, :list, required: true

  def render(assigns) do
    ~F"""
    <div class="list-group">
      {#for attempt <- @resource_attempts}
        <PageAttemptSummary attempt={attempt}/>
      {/for}
    </div>
    """
  end
end
