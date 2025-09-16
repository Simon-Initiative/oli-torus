defmodule OliWeb.RevisionHistory.Details do
  use OliWeb, :live_component

  alias OliWeb.Common.MonacoEditor
  alias Oli.Utils.SchemaResolver
  alias OliWeb.Components.Modal
  alias Phoenix.LiveView.JS
  alias Oli.Resources

  # keys we do not want to display in UI
  @ignored_keys [
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

  # keys that will be allowed to be edited by the user
  @editable_keys [
    :children,
    :objectives
  ]

  # keys where the ids contained within a list will be converted to links
  @linkable_keys [
    :children,
    :objectives,
    :relates_to
  ]

  def update(assigns, socket) do
    slug_mapper =
      fetch_resource_ids(@linkable_keys, assigns.revision)
      |> Resources.map_slugs_from_resources_ids()
      |> Enum.into(%{})

    socket =
      socket
      |> assign(assigns)
      |> assign(:slug_mapper, slug_mapper)

    {:ok, socket}
  end

  defp fetch_resource_ids(keys, revision) do
    Enum.reduce(keys, [], fn key, resource_ids ->
      case Map.get(revision, key) do
        list when is_list(list) ->
          list ++ resource_ids

        map when is_map(map) ->
          map
          |> Map.values()
          |> List.flatten(resource_ids)
      end
    end)
  end

  attr(:revision, :map)
  attr(:project, :map)
  attr(:editable_keys, :list, default: @editable_keys)
  attr(:linkable_keys, :list, default: @linkable_keys)
  attr(:modal_assigns, :map)

  def render(assigns) do
    ~H"""
    <div>
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
          <:title>Edit <i>{String.capitalize(@modal_assigns[:title])}</i> attribute</:title>
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
              <tr id="revision-table-title-attr">
                <td class="w-52"><strong>Title</strong></td>
                <td>{@revision.title}</td>
              </tr>
              <tr :for={{key, value} <- revision_details(@revision)} id={"revision-table-#{key}-attr"}>
                <td class="w-52">
                  <strong>{Phoenix.Naming.humanize(key)}</strong>
                </td>
                <td>
                  <button
                    :if={key in @editable_keys}
                    class="mx-2"
                    phx-click={JS.push("reset_monaco") |> JS.push("edit_attribute")}
                    phx-value-attr-key={key}
                  >
                    <i class="fas fa-edit" />
                  </button>
                  <.render_attribute
                    value={value}
                    key={key}
                    linkable_keys={@linkable_keys}
                    project_slug={@project.slug}
                    slug_mapper={@slug_mapper}
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  attr(:value, :string)
  attr(:key, :string)
  attr(:project_slug, :string)
  attr(:linkable_keys, :list)
  attr(:slug_mapper, :map)

  def render_attribute(
        %{
          key: key,
          linkable_keys: linkable_keys,
          value: value,
          project_slug: project_slug,
          slug_mapper: slug_mapper
        } = assigns
      ) do
    if key in linkable_keys do
      case value do
        list when is_list(list) ->
          assigns = %{parsed_list: parse_list(list, project_slug, slug_mapper)}

          ~H"""
          {raw(@parsed_list)}
          """

        map when is_map(map) ->
          assigns = %{parsed_map: parse_map(map, project_slug, slug_mapper)}

          ~H"""
          {raw(@parsed_map)}
          """

        _other ->
          ~H"""
          {json_encode_pretty(@value)}
          """
      end
    else
      ~H"""
      {json_encode_pretty(@value)}
      """
    end
  end

  defp parse_map(map, project_slug, slug_mapper) do
    map =
      Enum.map(map, fn {key, value} ->
        ~s["#{key}": #{maybe_parse_list(value, project_slug, slug_mapper)}]
      end)
      |> Enum.join(", ")

    "{#{map}}"
  end

  defp maybe_parse_list(list, project_slug, slug_mapper) when is_list(list) do
    parse_list(list, project_slug, slug_mapper)
  end

  defp maybe_parse_list(other, _project_slug, _slug_mapper) do
    json_encode_pretty(other)
  end

  defp parse_list(list, project_slug, slug_mapper) do
    parsed =
      Enum.map(list, fn resource_id ->
        ~s[<a href="#{history_url(project_slug, Map.get(slug_mapper, resource_id))}" data-phx-link="redirect" data-phx-link-state="push">#{resource_id}</a>]
      end)
      |> Enum.join(", ")

    "[#{parsed}]"
  end

  defp history_url(project_slug, revision_slug) do
    ~p{/project/#{project_slug}/history/slug/#{revision_slug}}
  end

  defp revision_details(revision) do
    revision
    |> Map.from_struct()
    |> Map.drop(@ignored_keys)
  end

  defp json_encode_pretty(json) do
    json
    |> Jason.encode!()
    |> Jason.Formatter.pretty_print()
  end
end
