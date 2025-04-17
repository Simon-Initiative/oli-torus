defmodule OliWeb.Dialogue.WindowLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Resources.ResourceType
  alias Oli.Delivery.Sections

  defp create_project(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # revisions...
    ## pages...
    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page")
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page")
      )

    ## modules...
    module_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_1_revision.resource_id, page_2_revision.resource_id]
      })

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [module_1_revision.resource_id]
      })

    ## root container...
    container_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          unit_1_revision.resource_id
        ],
        title: "Root Container"
      })

    all_revisions =
      [
        page_1_revision,
        page_2_revision,
        module_1_revision,
        unit_1_revision,
        container_revision
      ]

    # asociate resources to project
    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, %{
        project_id: project.id,
        resource_id: revision.resource_id
      })
    end)

    # publish project
    publication =
      insert(:publication, %{project: project, root_resource_id: container_revision.resource_id})

    # publish resources
    Enum.each(all_revisions, fn revision ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      })
    end)

    # create section...
    section =
      insert(:section,
        base_project: project,
        analytics_version: :v2,
        assistant_enabled: true
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)
    {:ok, _} = Sections.rebuild_contained_objectives(section)

    %{
      section: section,
      project: project,
      publication: publication,
      page_1: page_1_revision,
      page_2: page_2_revision,
      module_1: module_1_revision,
      unit_1: unit_1_revision
    }
  end

  describe "DOT AI BOT" do
    setup [:user_conn, :create_project]

    test "gets rendered correctly when no revision_id is provided", %{
      conn: conn,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} =
        live_isolated(
          conn,
          OliWeb.Dialogue.WindowLive,
          session: %{"section_slug" => section.slug, "current_user_id" => user.id}
        )

      assert has_element?(view, "div[id=ai_bot_collapsed]")
      assert has_element?(view, "div[id=ai_bot_conversation].hidden")
    end

    test "gets rendered correctly when a revision_id is provided", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1_revision
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} =
        live_isolated(
          conn,
          OliWeb.Dialogue.WindowLive,
          session: %{
            "section_slug" => section.slug,
            "current_user_id" => user.id,
            "revision_id" => page_1_revision.id
          }
        )

      assert has_element?(view, "div[id=ai_bot_collapsed]")
      assert has_element?(view, "div[id=ai_bot_conversation].hidden")
    end
  end
end
