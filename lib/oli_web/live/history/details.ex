defmodule OliWeb.RevisionHistory.Details do
  use OliWeb, :html

  alias OliWeb.Common.MonacoEditor
  alias Oli.Utils.SchemaResolver

  attr(:revision, :map)
  attr(:project, :map)

  def render(assigns) do
    attrs =
      ~w"slug deleted author_id previous_revision_id resource_type_id graded max_attempts late_start late_submit grace_period time_limit scoring_strategy_id activity_type_id parameters"

    assigns = Map.merge(assigns, %{attrs: attrs})

    ~H"""
    <div class="revision-details">
      <MonacoEditor.render
        id={"details-editor-#{@revision.id}"}
        height="500px"
        language="json"
        validate_schema_uri={SchemaResolver.get("page-content.schema.json").uri}
        default_value={json_encode_pretty(Map.get(@revision, :content))}
        default_options={
          %{
            "readOnly" => true,
            "selectOnLineNumbers" => true,
            "minimap" => %{"enabled" => false},
            "scrollBeyondLastLine" => false,
            "tabSize" => 2
          }
        }
        set_options="monaco_editor_set_options"
        set_value="monaco_editor_set_value"
        get_value="monaco_editor_get_value"
        use_code_lenses={[
          %{name: "activity-links", context: %{"projectSlug" => @project.slug}}
        ]}
      />
      <div>
        <table style="table-layout: fixed;" class="table table-bordered table-sm mt-3">
          <tbody>
            <tr>
              <td style="width:200px;"><strong>Title</strong></td>
              <td><%= @revision.title %></td>
            </tr>
            <tr>
              <td style="width:200px;"><strong>Objectives</strong></td>
              <td>
                <%= if Map.get(@revision.objectives, "attached") in [nil, []] do %>
                  <em>None</em>
                <% else %>
                  <ul>
                    <%= for objective <- Map.get(@revision.objectives, "attached") do %>
                      <li><%= objective %></li>
                    <% end %>
                  </ul>
                <% end %>
              </td>
            </tr>
            <%= for k <- @attrs do %>
              <tr>
                <td style="width:200px;"><strong><%= Phoenix.Naming.humanize(k) %></strong></td>
                <td><%= Map.get(@revision, String.to_existing_atom(k)) %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp json_encode_pretty(json) do
    json
    |> Jason.encode!()
    |> Jason.Formatter.pretty_print()
  end
end
