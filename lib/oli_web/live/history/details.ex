defmodule OliWeb.RevisionHistory.Details do
  use Phoenix.LiveComponent
  import Phoenix.HTML

  def render(assigns) do
    ~L"""
    <p><strong>Title: </strong> &quot;<%= @revision.title %>&quot;</p>
    <p><strong>Content: </strong></p>
    <code>
      <pre style="background-color: #EEEEEE;">
      <%= raw(Jason.encode!(@revision.content) |> Jason.Formatter.pretty_print()) %>
      </pre>
    </code>
    <p><strong>Objectives: </strong></p>
    <code>
      <pre style="background-color: #EEEEEE;">
      <%= raw(Jason.encode!(@revision.objectives) |> Jason.Formatter.pretty_print()) %>
      </pre>
    </code>
    """
  end
end
