defmodule OliWeb.RevisionHistory.Details do
  use Surface.Component

  alias OliWeb.Common.MonacoEditor

  prop revision, :map

  def render(assigns) do
    ~F"""
    <div id={"details-#{@revision.id}"} class="revision-details">
      <MonacoEditor
        height="500px"
        language="json"
        validate_schema_uri="http://torus.oli.cmu.edu/schemas/v0-1-0/resource.schema.json"
        default_value={json_encode_pretty(@revision)}
        default_options={%{
          "readOnly" => true,
          "selectOnLineNumbers" => true,
          "minimap" => %{"enabled" => false},
          "scrollBeyondLastLine" => false
        }}
        on_change="revision_json_change" />
    </div>
    """
  end

  defp json_encode_pretty(json) do
    json
    |> Jason.encode!()
    |> Jason.Formatter.pretty_print()
  end
end
