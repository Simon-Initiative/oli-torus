defmodule OliWeb.RevisionHistory.Details do
  use Surface.Component

  alias OliWeb.Common.MonacoEditor

  prop revision, :map

  def render(assigns) do
    attrs =
      ~w"slug deleted author_id previous_revision_id resource_type_id graded max_attempts time_limit scoring_strategy_id activity_type_id"

    ~F"""
    <div class="revision-details">
      <MonacoEditor
        id={"details-editor-#{@revision.id}"}
        height="500px"
        language="json"
        validate_schema_uri="http://torus.oli.cmu.edu/schemas/v0-1-0/page-content.schema.json"
        default_value={json_encode_pretty(Map.get(@revision, :content))}
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

      <div>
        <table
        style="table-layout: fixed;"
        class="table table-bordered table-sm mt-3">
          <tbody>
            <tr><td style="width:200px;"><strong>Title</strong></td><td>{ @revision.title }</td></tr>
            <tr>
              <td style="width:200px;"><strong>Objectives</strong></td>
              <td>
                {#case Map.get(@revision.objectives, "attached")}
                  {#match nil}
                      <em>None</em>
                  {#match []}
                      <em>None</em>
                  {#match objectives}
                    <ul>
                      {#for objective <- objectives}
                        <li>{objective}</li>
                      {#else}
                      {/for}
                    </ul>
                {/case}
              </td>
            </tr>
            {#for k <- attrs}
              <tr>
              <td style="width:200px;"><strong>{ Phoenix.Naming.humanize(k) }</strong></td>
              <td>{ Map.get(@revision, String.to_existing_atom(k)) }</td>
              </tr>
            {/for}
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
