defmodule OliWeb.RevisionHistory.Details do
  use OliWeb, :html

  alias OliWeb.Common.MonacoEditor
  alias Oli.Utils.SchemaResolver

  @rejected_keys [
    :title,
    :activity_type,
    :warnings,
    :previous_revision,
    :scoring_strategy,
    :author,
    :resource,
    :__meta__,
    :resource_type,
    :primary_resource,
    :content
  ]

  attr(:revision, :map)
  attr(:project, :map)

  def render(assigns) do
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
            <%= for {key, value} <- revision_details(@revision) do %>
              <tr>
                <td style="width:200px;"><strong><%= Phoenix.Naming.humanize(key) %></strong></td>
                <td><%= json_encode_pretty(value) %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp revision_details(revision) do
    revision
    |> Map.from_struct()
    |> Enum.reject(fn {k, _v} -> k in @rejected_keys end)
  end

  defp json_encode_pretty(json) do
    json
    |> Jason.encode!()
    |> Jason.Formatter.pretty_print()
  end
end
