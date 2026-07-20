defmodule Oli.Scenarios.EditAdaptivePageTest do
  use Oli.DataCase

  alias Oli.Scenarios

  @adaptive_activity_content """
  {
    "authoring": {
      "parts": [
        {
          "id": "capi_iframe_part",
          "type": "janus-capi-iframe",
          "src": "https://example.com/sim.html",
          "sourceType": "url",
          "configData": []
        }
      ],
      "rules": []
    },
    "partsLayout": [
      {
        "id": "capi_iframe_part",
        "type": "janus-capi-iframe",
        "src": "https://example.com/sim.html",
        "sourceType": "url",
        "configData": []
      }
    ]
  }
  """

  defp base_yaml(extra) do
    """
    - project:
        name: adaptive_project
        title: "Adaptive Project"
        root:
          container: "Root"
          children:
            - page: "Sim Page"

    - create_activity:
        project: adaptive_project
        title: "CAPI Activity"
        virtual_id: "capi_activity"
        scope: "embedded"
        type: "oli_adaptive"
        content_format: "json"
        content: |
    #{indent(@adaptive_activity_content, 6)}
    #{extra}
    """
  end

  defp indent(text, n) do
    pad = String.duplicate(" ", n)

    text
    |> String.split("\n")
    |> Enum.map_join("\n", &(pad <> &1))
  end

  describe "edit_adaptive_page directive" do
    test "converts page into adaptive page referencing the activity" do
      yaml =
        base_yaml("""
        - edit_adaptive_page:
            project: adaptive_project
            page: "Sim Page"
            activity_virtual_id: "capi_activity"
        """)

      result = Scenarios.execute_yaml(yaml)
      assert result.errors == []

      project = result.state.projects["adaptive_project"]
      revision = project.rev_by_title["Sim Page"]

      assert revision.content["advancedDelivery"] == true
      assert revision.content["advancedAuthoring"] == true
      assert revision.content["displayApplicationChrome"] == false
      assert revision.graded == false

      activity_revision =
        result.state.activity_virtual_ids[{"adaptive_project", "capi_activity"}]

      assert [%{"type" => "group", "layout" => "deck", "children" => children}] =
               revision.content["model"]

      assert [%{"type" => "activity-reference", "activity_id" => activity_id}] = children
      assert activity_id == activity_revision.resource_id
    end

    test "supports graded flag" do
      yaml =
        base_yaml("""
        - edit_adaptive_page:
            project: adaptive_project
            page: "Sim Page"
            activity_virtual_id: "capi_activity"
            graded: true
        """)

      result = Scenarios.execute_yaml(yaml)
      assert result.errors == []

      revision = result.state.projects["adaptive_project"].rev_by_title["Sim Page"]
      assert revision.graded == true
      assert revision.content["advancedDelivery"] == true
    end

    test "errors when activity virtual_id is unknown" do
      yaml =
        base_yaml("""
        - edit_adaptive_page:
            project: adaptive_project
            page: "Sim Page"
            activity_virtual_id: "missing_activity"
        """)

      result = Scenarios.execute_yaml(yaml)

      assert [{_directive, message}] = result.errors
      assert message =~ "missing_activity"
    end

    test "errors when page is unknown" do
      yaml =
        base_yaml("""
        - edit_adaptive_page:
            project: adaptive_project
            page: "No Such Page"
            activity_virtual_id: "capi_activity"
        """)

      result = Scenarios.execute_yaml(yaml)

      assert [{_directive, message}] = result.errors
      assert message =~ "No Such Page"
    end

    test "errors when the referenced activity is not adaptive" do
      yaml = """
      - project:
          name: adaptive_project
          title: "Adaptive Project"
          root:
            container: "Root"
            children:
              - page: "Sim Page"

      - create_activity:
          project: adaptive_project
          title: "Plain MC"
          virtual_id: "plain_mc"
          type: "oli_multiple_choice"
          content: |
            stem_md: "What is 2 + 2?"
            choices:
              - id: "a"
                body_md: "4"
                score: 1
              - id: "b"
                body_md: "5"
                score: 0

      - edit_adaptive_page:
          project: adaptive_project
          page: "Sim Page"
          activity_virtual_id: "plain_mc"
      """

      result = Scenarios.execute_yaml(yaml)

      assert [{_directive, message}] = result.errors
      assert message =~ "not an oli_adaptive activity"
    end
  end
end
