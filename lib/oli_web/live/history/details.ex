defmodule OliWeb.RevisionHistory.Details do
  use Phoenix.LiveComponent
  import Phoenix.HTML

  def render(assigns) do

    attrs = ~w"slug deleted author_id previous_revision_id resource_type_id graded max_attempts time_limit scoring_strategy_id activity_type_id"

    ~L"""
    <table
      style="table-layout: fixed;"
      class="table table-bordered table-sm">
      <thead class="thead-dark">
        <tr><th style="width:100px;">Attribute</th><th>Value</th></tr>
      </thead>
      <tbody>
        <tr><td style="width:100px;"><strong>Title</strong></td><td><%= @revision.title %></td></tr>
        <tr>
          <td style="width:100px;"><strong>Objectives</strong></td>
          <td>
            <code>
            <pre style="background-color: #EEEEEE;">
            <%= raw(Jason.encode!(@revision.objectives) |> Jason.Formatter.pretty_print()) %>
            </pre>
            </code>
          </td>
        </tr>
        <tr>
          <td style="width:100px;"><strong>Content</strong></td>
          <td>
            <code>
            <pre style="background-color: #EEEEEE;">
            <%= raw(Jason.encode!(@revision.content) |> Jason.Formatter.pretty_print()) %>
            </pre>
            </code>
          </td>
        </tr>
        <%= for k <- attrs do %>
          <tr>
          <td style="width:100px;"><strong><%= k %></strong></td>
          <td><%= Map.get(@revision, String.to_existing_atom(k)) %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end
end
