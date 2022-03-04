defmodule OliWeb.RevisionHistory.Details do
  use Surface.Component

  alias OliWeb.Common.MonacoEditor

  prop revision, :map

  def render(assigns) do
    ~F"""
    <div class="revision-details">
      <MonacoEditor
        id={"details-editor-#{@revision.id}"}
        height="500px"
        language="json"
        validate_schema_uri="http://torus.oli.cmu.edu/schemas/v0-1-0/resource.schema.json"
        default_value={json_encode_pretty(@revision)}
        default_options={%{
          "readOnly" => true,
          "selectOnLineNumbers" => true,
          "minimap" => %{"enabled" => false},
          "scrollBeyondLastLine" => false,
          "tabSize" => 2
        }}
        set_options="monaco_editor_set_options"
        set_value="monaco_editor_set_value"
        get_value="monaco_editor_get_value" />
    </div>
    """
  end

  defp json_encode_pretty(json) do
    json
    |> Jason.encode!()
    |> Jason.Formatter.pretty_print()
  end
end
