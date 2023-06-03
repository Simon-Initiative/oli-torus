defmodule OliWeb.Progress.AttemptHistory do
  use Surface.Component
  alias OliWeb.Progress.PageAttemptSummary

  prop resource_attempts, :list, required: true
  prop section, :struct, required: true
  prop ctx, :struct, required: true
  prop revision, :struct, required: true

  def render(assigns) do
    ~F"""
    <div class="list-group">
      {#for attempt <- @resource_attempts}
        <PageAttemptSummary id={attempt.id} revision={@revision} attempt={attempt} section={@section} {=@ctx}/>
      {/for}
    </div>
    """
  end
end
