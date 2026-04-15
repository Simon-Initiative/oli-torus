defmodule OliWeb.Delivery.Student.PracticeLiveTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType

  defp create_practice_project(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    practice_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Practice Page One",
        purpose: :deliberate_practice
      )

    practice_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Practice Page Two",
        purpose: :deliberate_practice
      )

    root_practice_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Root Practice Page",
        purpose: :deliberate_practice
      )

    unit_1_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [practice_1_revision.resource_id, practice_2_revision.resource_id],
        title: "Introduction"
      })

    container_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [unit_1_revision.resource_id, root_practice_revision.resource_id],
        title: "Root Container"
      })

    all_revisions = [
      practice_1_revision,
      practice_2_revision,
      root_practice_revision,
      unit_1_revision,
      container_revision
    ]

    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, %{
        project_id: project.id,
        resource_id: revision.resource_id
      })
    end)

    publication =
      insert(:publication, %{project: project, root_resource_id: container_revision.resource_id})

    Enum.each(all_revisions, fn revision ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      })
    end)

    section =
      insert(:section,
        base_project: project,
        title: "The best course ever!",
        start_date: ~U[2023-10-30 20:00:00Z],
        analytics_version: :v2,
        open_and_free: true,
        lti_1p3_deployment: nil,
        lti_1p3_deployment_id: nil
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)
    section = Oli.Delivery.Sections.PostProcessing.apply(section, :all)

    %{
      section: section,
      practice_1: practice_1_revision,
      root_practice: root_practice_revision
    }
  end

  describe "student" do
    setup [:user_conn, :create_practice_project]

    test "hides container headings when curriculum numbering is disabled", %{
      conn: conn,
      user: user,
      section: section,
      practice_1: practice_1,
      root_practice: root_practice
    } do
      {:ok, section} =
        Sections.update_section(section, %{display_curriculum_item_numbering: false})

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/practice")

      refute has_element?(view, "h2", "Unit 1: Introduction")
      refute has_element?(view, "h2", "Curriculum 1: Root Container")
      assert has_element?(view, "h5", practice_1.title)
      assert has_element?(view, "h5", root_practice.title)
    end

    test "hides headings for excluded unnumbered units", %{
      conn: conn,
      user: user,
      section: section,
      practice_1: practice_1,
      root_practice: root_practice
    } do
      unit_1 =
        Sections.get_top_level_unit_resources(section.id)
        |> List.first()

      {:ok, section} =
        Sections.update_section(section, %{unnumbered_unit_ids: [unit_1.resource_id]})

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/practice")

      refute has_element?(view, "h2", "Unit 1: Introduction")
      refute has_element?(view, "h2", "Introduction")
      assert has_element?(view, "h5", practice_1.title)
      assert has_element?(view, "h5", root_practice.title)
    end

    test "renders the practice page title with high-contrast text", %{
      conn: conn,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/practice")

      assert has_element?(view, "h1.text-Text-text-white", "Your Practice Pages")
      assert has_element?(view, "h2.text-Text-text-high", "Unit 1: Introduction")
    end
  end
end
