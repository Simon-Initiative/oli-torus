defmodule OliWeb.RevisionHistory.Details do
  use OliWeb, :html

  alias OliWeb.Common.MonacoEditor
  alias Oli.Utils.SchemaResolver
  alias OliWeb.Components.Modal
  alias Phoenix.LiveView.JS

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

  @editable_keys [
    :children,
    :objectives
  ]

  attr(:revision, :map)
  attr(:project, :map)
  attr(:editable_keys, :list, default: @editable_keys)
  attr(:modal_assigns, :map)

  def render(assigns) do
    ~H"""
    <div
      :if={@modal_assigns}
      id="edit_attribute_modal_trigger"
      data-show_edit_attribute_modal={Modal.show_modal("edit_attribute_modal")}
    >
      <Modal.modal
        id="edit_attribute_modal"
        on_confirm={
          JS.push("save_edit_attribute")
          |> JS.add_class("fixed top-20 z-10", to: "#live_flash_container")
          |> Modal.hide_modal("edit_attribute_modal")
        }
        on_cancel={Modal.hide_modal("edit_attribute_modal")}
      >
        <:title>Edit <i><%= String.capitalize(@modal_assigns[:title]) %></i> attribute</:title>
        <MonacoEditor.render
          id="attribute-monaco-editor"
          height="200px"
          language="json"
          validate_schema_uri={SchemaResolver.get("page-content.schema.json").uri}
          default_value={json_encode_pretty(Map.get(@revision, @modal_assigns[:key]))}
          default_options={
            %{
              "readOnly" => false,
              "selectOnLineNumbers" => true,
              "minimap" => %{"enabled" => false},
              "scrollBeyondLastLine" => false,
              "tabSize" => 2
            }
          }
          set_options="monaco_editor_set_attribute_options"
          set_value="monaco_editor_set_attribute_value"
          get_value="monaco_editor_get_attribute_value"
          use_code_lenses={[
            %{name: "activity-links", context: %{"projectSlug" => @project.slug}}
          ]}
        />
        <:cancel>Cancel</:cancel>
        <:confirm>Save</:confirm>
      </Modal.modal>
    </div>
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
              <td class="w-52"><strong>Title</strong></td>
              <td><%= @revision.title %></td>
            </tr>
            <tr :for={{key, value} <- revision_details(@revision)}>
              <td class="w-52">
                <strong><%= Phoenix.Naming.humanize(key) %></strong>
              </td>
              <td>
                <button
                  :if={key in @editable_keys}
                  class="mx-2"
                  phx-click={JS.push("reset-monaco") |> JS.push("edit-attribute")}
                  phx-value-attr-key={key}
                >
                  <i class="fas fa-edit" />
                </button>
                <%= json_encode_pretty(value) %>
              </td>
            </tr>
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
