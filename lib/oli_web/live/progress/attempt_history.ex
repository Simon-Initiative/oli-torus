defmodule OliWeb.Progress.AttemptHistory do
  use OliWeb, :html
  alias OliWeb.Progress.PageAttemptSummary

  attr(:resource_attempts, :list, required: true)
  attr(:section, :map, required: true)
  attr(:ctx, :map, required: true)
  attr(:revision, :map, required: true)
  attr(:request_path, :string, default: "")

  def render(assigns) do
    ~H"""
    <div class="list-group mb-5">
      <%= for attempt <- @resource_attempts do %>
        <PageAttemptSummary.render
          revision={@revision}
          attempt={attempt}
          section={@section}
          ctx={@ctx}
          request_path={@request_path}
        />
      <% end %>
    </div>
    """
  end
end
