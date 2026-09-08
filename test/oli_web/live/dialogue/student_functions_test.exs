defmodule OliWeb.Dialogue.StudentFunctionsTest do
  use Oli.DataCase, async: true

  import Mox
  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType
  alias Oli.Test.MockOpenAIClient
  alias OliWeb.Dialogue.StudentFunctions

  @tool_exposed_event [:oli, :genai, :adaptive_context, :tool_exposed]
  @tool_called_event [:oli, :genai, :adaptive_context, :tool_called]

  describe "functions_for_session/1" do
    test "keeps the adaptive tool hidden outside supported adaptive sessions" do
      refute function_names(%{adaptive?: true}) |> Enum.member?("adaptive_page_context")
      refute function_names(%{}) |> Enum.member?("adaptive_page_context")
    end

    test "exposes the adaptive tool only when adaptive session context is complete" do
      handler = attach_telemetry([@tool_exposed_event])

      functions =
        StudentFunctions.functions_for_session(%{
          adaptive?: true,
          current_user_id: 12,
          section_id: 34
        })

      assert Enum.map(functions, & &1.name) |> Enum.member?("adaptive_page_context")

      adaptive_function = Enum.find(functions, &(&1.name == "adaptive_page_context"))

      assert adaptive_function.parameters.required == ["activity_attempt_guid"]
      assert Map.keys(adaptive_function.parameters.properties) == [:activity_attempt_guid]
      assert adaptive_function.trusted_arguments == %{"current_user_id" => 12, "section_id" => 34}

      assert_receive {:telemetry_event, @tool_exposed_event, %{count: 1}, metadata}
      assert metadata.section_id == 34

      :telemetry.detach(handler)
    end
  end

  describe "adaptive_page_context/1" do
    test "fails closed on invalid arguments" do
      handler = attach_telemetry([@tool_called_event])

      assert StudentFunctions.adaptive_page_context(%{
               "activity_attempt_guid" => " ",
               "current_user_id" => "bad",
               "section_id" => "oops"
             }) == fail_closed_message()

      assert_receive {:telemetry_event, @tool_called_event, %{count: 1}, metadata}
      assert metadata.section_id == nil

      :telemetry.detach(handler)
    end
  end

  describe "relevant_course_content/1" do
    setup do
      author = insert(:author)
      project = insert(:project, authors: [author])

      page_a_revision =
        insert(:revision, resource_type_id: ResourceType.id_for_page(), title: "Page A")

      module_a_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_container(),
          children: [page_a_revision.resource_id],
          title: "Introduction to Math"
        )

      unit1_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_container(),
          children: [module_a_revision.resource_id],
          title: "Foundations"
        )

      page_b_revision =
        insert(:revision, resource_type_id: ResourceType.id_for_page(), title: "Page B")

      module_b_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_container(),
          children: [page_b_revision.resource_id],
          title: "Statistics Basics"
        )

      unit2_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_container(),
          children: [module_b_revision.resource_id],
          title: "Data Analysis"
        )

      container_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_container(),
          children: [unit1_revision.resource_id, unit2_revision.resource_id],
          title: "Root Container"
        )

      all_revisions = [
        page_a_revision,
        module_a_revision,
        unit1_revision,
        page_b_revision,
        module_b_revision,
        unit2_revision,
        container_revision
      ]

      Enum.each(all_revisions, fn revision ->
        insert(:project_resource, project_id: project.id, resource_id: revision.resource_id)
      end)

      publication =
        insert(:publication, project: project, root_resource_id: container_revision.resource_id)

      Enum.each(all_revisions, fn revision ->
        insert(:published_resource,
          publication: publication,
          resource: revision.resource,
          revision: revision,
          author: author
        )
      end)

      section =
        insert(:section,
          base_project: project,
          context_id: UUID.uuid4(),
          open_and_free: true,
          registration_open: true,
          type: :enrollable
        )

      {:ok, section} = Sections.create_section_resources(section, publication)

      [section: section, unit1_resource: unit1_revision.resource]
    end

    test "uses suppression-aware numbering in the layout, falling back to the bare title for a suppressed unit",
         %{section: section, unit1_resource: unit1_resource} do
      {:ok, section} =
        Sections.update_section(section, %{unnumbered_unit_ids: [unit1_resource.id]})

      MockOpenAIClient
      |> expect(:embeddings, fn _args, _opts -> {:error, :not_found} end)

      result =
        StudentFunctions.relevant_course_content(%{
          "student_input" => "test",
          "section_id" => section.id
        })

      # "Foundations" is suppressed: bare title, no numbering prefix at all.
      assert "Foundations" in result.layout
      refute Enum.any?(result.layout, &(&1 =~ "Foundations" and &1 != "Foundations"))

      # "Introduction to Math" sits inside the suppressed "Foundations", so it too falls
      # back to its bare title -- suppression cascades to descendants.
      assert "Introduction to Math" in result.layout

      # "Data Analysis" is renumbered to "Unit 1" since "Foundations" no longer consumes a
      # numbering slot; "Statistics Basics" (its only module) is renumbered to "Module 1".
      assert "Unit 1: Data Analysis" in result.layout
      assert "Module 1: Statistics Basics" in result.layout

      # "Introduction to Math" is document-first among the two modules (it's nested under
      # the first unit), so it must still come before "Statistics Basics" in the layout --
      # its suppressed (nil) display numbering must not push it to the end of the list.
      assert Enum.find_index(result.layout, &(&1 == "Introduction to Math")) <
               Enum.find_index(result.layout, &(&1 == "Module 1: Statistics Basics"))
    end

    test "matches canonical numbering in the layout when no unit is suppressed", %{
      section: section
    } do
      MockOpenAIClient
      |> expect(:embeddings, fn _args, _opts -> {:error, :not_found} end)

      result =
        StudentFunctions.relevant_course_content(%{
          "student_input" => "test",
          "section_id" => section.id
        })

      assert "Unit 1: Foundations" in result.layout
      assert "Module 1: Introduction to Math" in result.layout
      assert "Unit 2: Data Analysis" in result.layout
      # Module numbering is a single sequential counter across the whole course, not reset
      # per unit, so "Statistics Basics" (the second module in document order) is "Module 2".
      assert "Module 2: Statistics Basics" in result.layout
    end
  end

  defp attach_telemetry(events) do
    handler_id = "student-functions-telemetry-test-#{System.unique_integer([:positive])}"
    parent = self()

    :ok =
      :telemetry.attach_many(
        handler_id,
        events,
        fn event_name, measurements, metadata, _config ->
          send(parent, {:telemetry_event, event_name, measurements, metadata})
        end,
        nil
      )

    handler_id
  end

  defp function_names(session_context) do
    StudentFunctions.functions_for_session(session_context)
    |> Enum.map(& &1.name)
  end

  defp fail_closed_message do
    "Adaptive page context is unavailable for this request.\nAnswer only from other available lesson context and do not infer unseen adaptive screens."
  end
end
