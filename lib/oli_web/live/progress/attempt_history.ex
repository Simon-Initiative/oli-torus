defmodule OliWeb.Progress.AttemptHistory do
  use OliWeb, :html
  alias OliWeb.Progress.PageAttemptSummary

  attr(:resource_attempts, :list, required: true)
  attr(:section, :map, required: true)
  attr(:ctx, :map, required: true)
  attr(:revision, :map, required: true)
  attr(:can_delete_attempt, :boolean, default: false)
  attr(:request_path, :string, default: "")

  def render(assigns) do
    ~H"""
    <% latest_attempt_id = latest_attempt_id(@resource_attempts) %>
    <div class="list-group mb-5">
      <%= for attempt <- @resource_attempts do %>
        <PageAttemptSummary.render
          revision={@revision}
          attempt={attempt}
          section={@section}
          ctx={@ctx}
          can_delete_attempt={@can_delete_attempt && attempt.id == latest_attempt_id}
          request_path={@request_path}
        />
      <% end %>
    </div>
    """
  end

  defp latest_attempt_id([]), do: nil

  defp latest_attempt_id(attempts) do
    Enum.max_by(attempts, &{&1.attempt_number, &1.id}).id
  end
end
