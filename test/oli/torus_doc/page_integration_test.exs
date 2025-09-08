defmodule Oli.TorusDoc.PageIntegrationTest do
  use ExUnit.Case, async: true
  alias Oli.TorusDoc.PageConverter

  test "parses the example page.yaml file" do
    yaml = File.read!("output/page.yaml")

    assert {:ok, json} = PageConverter.from_yaml(yaml)

    # Verify page structure
    assert json["type"] == "Page"
    assert json["id"] == "page-course-intake"
    assert json["title"] == "Course Intake & Pre-Survey"
    assert json["isGraded"] == false

    # Verify content structure
    assert json["content"]["version"] == "0.1.0"
    model = json["content"]["model"]

    # Should have 4 blocks: prose, group, survey, prose
    assert length(model) == 4

    # First block: prose with "# Welcome"
    [first_prose, group, survey, last_prose] = model
    assert first_prose["type"] == "content"
    assert is_list(first_prose["children"])

    # Should contain h1 and p from markdown
    [h1, p] = first_prose["children"]
    assert h1["type"] == "h1"
    assert p["type"] == "p"

    # Group block (with activity that gets placeholder treatment for now)
    assert group["type"] == "group"
    assert is_list(group["children"])
    # Group contains prose and activity (activity becomes placeholder for now)

    # Survey block
    assert survey["type"] == "survey"
    assert survey["id"] == "pre-course-survey"
    assert survey["title"] == "Pre-Course Background Survey"
    assert is_list(survey["children"])

    # Survey should have 4 children (2 prose, 1 bank-selection, 1 activity)
    assert length(survey["children"]) == 4

    [survey_prose1, bank_selection, survey_prose2, activity] = survey["children"]

    # First survey prose: "## Your Background"
    assert survey_prose1["type"] == "content"
    [h2_bg] = survey_prose1["children"]
    assert h2_bg["type"] == "h2"

    # Activity (now properly converted)
    assert activity["type"] == "activity-reference"
    assert activity["activitySlug"]

    # Bank selection (now properly converted)
    assert bank_selection["type"] == "selection"
    assert bank_selection["count"] == 2
    assert bank_selection["logic"]["conditions"]["operator"] == "all"

    # Check the clauses in the bank selection
    conditions = bank_selection["logic"]["conditions"]["children"]
    assert length(conditions) == 2

    [cond1, cond2] = conditions
    assert cond1["fact"] == "tags"
    assert cond1["operator"] == "contains"
    assert cond1["value"] == "kinematics"

    assert cond2["fact"] == "type"
    assert cond2["operator"] == "equal"
    assert cond2["value"] == "oli_multiple_choice"

    # Second survey prose: "## Course Logistics"
    assert survey_prose2["type"] == "content"
    [h2_logistics] = survey_prose2["children"]
    assert h2_logistics["type"] == "h2"

    # Last prose block
    assert last_prose["type"] == "content"
    [last_p] = last_prose["children"]
    assert last_p["type"] == "p"
  end

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
