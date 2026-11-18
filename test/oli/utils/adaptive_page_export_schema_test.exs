defmodule Oli.Utils.AdaptivePageExportSchemaTest do
  use Oli.DataCase

  alias Oli.Interop.Export
  alias Oli.Resources.ResourceType
  alias Oli.Utils.{JSONValidation, SchemaResolver}

  import Oli.Factory

  test "the real course exporter produces a valid Adaptive Page envelope" do
    author = insert(:author)
    %{project: project, publication: publication} = insert_project_with_resource(author)
    resource = insert(:resource)
    insert(:project_resource, project: project, resource: resource)

    revision =
      insert(:revision,
        resource: resource,
        author: author,
        resource_type_id: ResourceType.id_for_page(),
        content: %{"advancedAuthoring" => true, "advancedDelivery" => true, "model" => []},
        objectives: %{"attached" => []},
        ai_enabled: true,
        intro_content: %{},
        explanation_strategy: %Oli.Resources.ExplanationStrategy{type: :none},
        collab_space_config: %Oli.Resources.Collaboration.CollabSpaceConfig{}
      )

    insert(:published_resource,
      publication: publication,
      resource: resource,
      revision: revision,
      author: author
    )

    archive = Export.export(project)
    assert {:ok, entries} = :zip.unzip(archive, [:memory])

    {_name, json} =
      Enum.find(entries, fn {name, _} -> name == String.to_charlist("#{resource.id}.json") end)

    export = Jason.decode!(json)
    assert is_list(export["objectives"])
    assert export["purpose"] == "foundation"
    assert export["aiEnabled"] == true
    assert Map.has_key?(export, "assessmentMode")
    assert Map.has_key?(export, "introContent")

    root = SchemaResolver.resolve("adaptive-page.schema.json")
    assert :ok = JSONValidation.validate(root, export)
    assert :ok = JSONValidation.validate(SchemaResolver.resolve("page.schema.json"), export)

    for {key, bad} <- [
          {"aiEnabled", "true"},
          {"relatesTo", [nil]},
          {"maxAttempts", "1"},
          {"purpose", "example"},
          {"retakeMode", "unknown"},
          {"assessmentMode", "unknown"},
          {"durationMinutes", "10"},
          {"collabSpace", %{"status" => "unknown"}},
          {"explanationStrategy", %{"type" => "none", "typo" => true}}
        ] do
      assert {:error, [_ | _]} = JSONValidation.validate(root, Map.put(export, key, bad))
    end
  end
end
