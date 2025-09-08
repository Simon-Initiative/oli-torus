defmodule Oli.TorusDoc.PageIntegrationTest do
  use ExUnit.Case, async: true
  alias Oli.TorusDoc.PageConverter

  test "creates valid JSON according to schema requirements" do
    yaml = """
    type: page
    id: schema-test
    title: Schema Test Page
    graded: true
    blocks:
      - type: prose
        body_md: Test content
    """

    assert {:ok, json} = PageConverter.from_yaml(yaml)

    # Verify all required fields are present
    required_fields = [
      "type",
      "id",
      "title",
      "isGraded",
      "content",
      "objectives",
      "tags",
      "unresolvedReferences"
    ]

    for field <- required_fields do
      assert Map.has_key?(json, field), "Missing required field: #{field}"
    end

    # Verify content structure
    assert json["content"]["version"] == "0.1.0"
    assert is_list(json["content"]["model"])

    # Verify objectives structure
    assert is_map(json["objectives"])
    assert is_list(json["objectives"]["attached"])

    # Verify arrays
    assert is_list(json["tags"])
    assert is_list(json["unresolvedReferences"])
  end

  test "properly handles markdown within blocks" do
    yaml = """
    type: page
    id: markdown-test
    title: Markdown Test
    blocks:
      - type: prose
        body_md: |
          # Heading 1
          ## Heading 2
          
          Regular paragraph with **bold** and *italic*.
          
          - List item 1
          - List item 2
          
          1. Ordered item
          2. Another item
          
          [Link text](https://example.com)
          
      - type: survey
        id: survey-1
        title: Survey with Markdown
        intro_md: |
          This survey contains **formatted** text.
        blocks:
          - type: prose
            body_md: |
              ### Survey Section
              
              With some content.
    """

    assert {:ok, json} = PageConverter.from_yaml(yaml)

    # Check the prose block converted properly
    [prose, survey] = json["content"]["model"]

    # Prose should have multiple children from markdown
    assert prose["type"] == "content"
    children = prose["children"]

    # Should have h1, h2, p (with formatting), ul, ol, p (with link)
    assert Enum.any?(children, &(&1["type"] == "h1"))
    assert Enum.any?(children, &(&1["type"] == "h2"))
    assert Enum.any?(children, &(&1["type"] == "ul"))
    assert Enum.any?(children, &(&1["type"] == "ol"))

    # Check survey blocks
    assert survey["type"] == "survey"
    assert length(survey["children"]) == 1

    [survey_content] = survey["children"]
    assert survey_content["type"] == "content"

    # Should have h3 and p from markdown
    survey_children = survey_content["children"]
    assert Enum.any?(survey_children, &(&1["type"] == "h3"))
    assert Enum.any?(survey_children, &(&1["type"] == "p"))
  end
end
