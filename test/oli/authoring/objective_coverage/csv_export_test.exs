defmodule Oli.Authoring.ObjectiveCoverage.CsvExportTest do
  use ExUnit.Case, async: true

  alias Oli.Authoring.ObjectiveCoverage
  alias Oli.Authoring.ObjectiveCoverage.CsvExport
  alias Oli.Branding.CustomLabels
  alias Oli.Resources.ResourceType

  test "exports one row per objective/activity/page relationship with custom course locations" do
    model =
      ObjectiveCoverage.build([
        row(:objective, 1, title: "Alpha Objective", children: [2]),
        row(:objective, 2, title: "Alpha Sub-Objective"),
        row(:container, 100, title: "Root", children: [110]),
        row(:container, 110, title: "Foundations", children: [120]),
        row(:container, 120, title: "Motion", children: [200, 201]),
        row(:page, 200, title: "Vectors", activity_refs: [300, 301]),
        row(:page, 201, title: "Acceleration", activity_refs: [300]),
        row(:activity, 300,
          title: "Direct Quiz",
          objectives: %{"part" => [1]},
          activity_type_id: 11
        ),
        row(:activity, 301,
          title: "Child Check",
          objectives: %{"part" => [2]},
          activity_type_id: 2
        ),
        row(:activity, 302,
          title: "Banked Practice",
          objectives: %{"part" => [2]},
          activity_type_id: 15,
          scope: :banked
        )
      ])

    customizations = %CustomLabels{unit: "Book", module: "Chapter", section: "Lesson"}

    assert CsvExport.rows(model, customizations, %{
             11 => "Multiple Choice",
             2 => "CATA",
             15 => "Input"
           }) == [
             [
               "LO 1",
               "Alpha Objective",
               "",
               "Multiple Choice",
               "Direct Quiz",
               "Acceleration",
               "Book 1: Foundations > Chapter 1: Motion"
             ],
             [
               "LO 1",
               "Alpha Objective",
               "",
               "Multiple Choice",
               "Direct Quiz",
               "Vectors",
               "Book 1: Foundations > Chapter 1: Motion"
             ],
             [
               "LO 1",
               "Alpha Objective",
               "Alpha Sub-Objective",
               "Input",
               "Banked Practice",
               "",
               ""
             ],
             [
               "LO 1",
               "Alpha Objective",
               "Alpha Sub-Objective",
               "CATA",
               "Child Check",
               "Vectors",
               "Book 1: Foundations > Chapter 1: Motion"
             ]
           ]
  end

  test "preserves authored curriculum order when numbering locations" do
    model =
      ObjectiveCoverage.build(
        [
          row(:container, 50, title: "Unattached Container", children: [400]),
          row(:objective, 1, title: "Objective"),
          row(:container, 100, title: "Root", children: [300, 200]),
          row(:container, 200, title: "Second Book", children: [400]),
          row(:container, 300, title: "First Book"),
          row(:page, 400, title: "Page", activity_refs: [500]),
          row(:activity, 500,
            title: "Activity",
            objectives: %{"part" => [1]},
            activity_type_id: 11
          )
        ],
        %{root_resource_id: 100}
      )

    [row] = CsvExport.rows(model, nil, %{11 => "Multiple Choice"})

    assert List.last(row) == "Unit 2: Second Book"
  end

  test "applies the current search and sort before assigning LO labels" do
    model =
      ObjectiveCoverage.build([
        row(:objective, 1, title: "Alpha Objective"),
        row(:objective, 2, title: "Beta Objective"),
        row(:activity, 10,
          title: "Alpha Activity",
          objectives: %{"part" => [1]},
          activity_type_id: 11
        ),
        row(:activity, 20,
          title: "Beta Activity",
          objectives: %{"part" => [2]},
          activity_type_id: 11
        )
      ])

    assert [["LO 1", "Alpha Objective" | _]] =
             CsvExport.rows(model, nil, %{11 => "Multiple Choice"}, %{"query" => "alpha"})

    assert [
             ["LO 1", "Beta Objective" | _],
             ["LO 2", "Alpha Objective" | _]
           ] =
             CsvExport.rows(model, nil, %{11 => "Multiple Choice"}, %{
               "sort_by" => "title",
               "sort_order" => "desc"
             })
  end

  test "matches the objective table's attachment count sorting" do
    model =
      ObjectiveCoverage.build([
        row(:objective, 1, title: "Parent", children: [2]),
        row(:objective, 2, title: "Child"),
        row(:objective, 3, title: "Direct"),
        row(:page, 20, title: "Child Page", objectives: %{"attached" => [2]}),
        row(:activity, 30,
          title: "Child Activity",
          objectives: %{"part" => [2]},
          activity_type_id: 11
        ),
        row(:activity, 31,
          title: "Direct Activity",
          objectives: %{"part" => [3]},
          activity_type_id: 11
        )
      ])

    assert [["LO 1", "Parent" | _], ["LO 2", "Direct" | _]] =
             CsvExport.rows(model, nil, %{11 => "Multiple Choice"}, %{
               "sort_by" => "page_attachments_count",
               "sort_order" => "desc"
             })

    assert [["LO 1", "Direct" | _], ["LO 2", "Parent" | _]] =
             CsvExport.rows(model, nil, %{11 => "Multiple Choice"}, %{
               "sort_by" => "activity_attachments_count",
               "sort_order" => "desc"
             })
  end

  test "encodes headers for an empty result and neutralizes spreadsheet formulas" do
    model =
      ObjectiveCoverage.build([
        row(:objective, 1, title: "=FORMULA"),
        row(:activity, 10,
          title: "+FORMULA",
          objectives: %{"part" => [1]},
          activity_type_id: 11
        )
      ])

    encoded = CsvExport.encode(model, nil, %{11 => "Multiple Choice"})
    headers = CsvExport.headers()

    assert [
             ^headers,
             ["LO 1", "'=FORMULA", "", "Multiple Choice", "'+FORMULA", "", ""]
           ] =
             NimbleCSV.RFC4180.parse_string(encoded, skip_headers: false)

    header_only =
      CsvExport.encode(model, nil, %{11 => "Multiple Choice"}, %{"query" => "no match"})

    assert [headers] ==
             NimbleCSV.RFC4180.parse_string(header_only, skip_headers: false)
  end

  defp row(type, resource_id, attrs) do
    %{
      project_id: 1,
      publication_id: 2,
      revision_id: resource_id + 1_000,
      resource_id: resource_id,
      resource_type_id: resource_type_id(type),
      slug: "resource-#{resource_id}",
      title: Keyword.get(attrs, :title, "Resource #{resource_id}"),
      deleted: false,
      objectives: Keyword.get(attrs, :objectives, %{}),
      children: Keyword.get(attrs, :children, []),
      graded: Keyword.get(attrs, :graded, false),
      activity_refs: Keyword.get(attrs, :activity_refs, []),
      scope: Keyword.get(attrs, :scope, :embedded),
      activity_type_id: Keyword.get(attrs, :activity_type_id)
    }
  end

  defp resource_type_id(:objective), do: ResourceType.id_for_objective()
  defp resource_type_id(:container), do: ResourceType.id_for_container()
  defp resource_type_id(:page), do: ResourceType.id_for_page()
  defp resource_type_id(:activity), do: ResourceType.id_for_activity()
end
