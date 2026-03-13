defmodule OliWeb.Dialogue.WindowLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Resources.ResourceType
  alias Oli.Delivery.Sections
  alias Oli.GenAI.Completions.ServiceConfig

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
        resource_type_id: ResourceType.get_id_by_type("page"),
        ai_enabled: false
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
          session: %{
            "section_slug" => section.slug,
            "current_user_id" => user.id,
            "service_config" => stub_service_config()
          }
        )

      assert has_element?(view, "div[id=ai_bot_collapsed]")
      assert has_element?(view, "div[id=ai_bot_conversation].hidden")
    end

    test "does not render when no revision_id is provided and page has ai disabled", %{
      conn: conn,
      user: user,
      section: section,
      page_2: page_2_revision
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} =
        live_isolated(
          conn,
          OliWeb.Dialogue.WindowLive,
          session: %{
            "section_slug" => section.slug,
            "current_user_id" => user.id,
            "resource_id" => page_2_revision.resource_id
          }
        )

      refute has_element?(view, "div[id=ai_bot_collapsed]")
      refute has_element?(view, "div[id=ai_bot_conversation]")
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
            "resource_id" => page_1_revision.resource_id,
            "revision_id" => page_1_revision.id,
            "service_config" => stub_service_config()
          }
        )

      assert has_element?(view, "div[id=ai_bot_collapsed]")
      assert has_element?(view, "div[id=ai_bot_conversation].hidden")
    end

    test "does not render when revision_id does not match the section resource", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1_revision,
      page_2: page_2_revision
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} =
        live_isolated(
          conn,
          OliWeb.Dialogue.WindowLive,
          session: %{
            "section_slug" => section.slug,
            "current_user_id" => user.id,
            "resource_id" => page_1_revision.resource_id,
            "revision_id" => page_2_revision.id
          }
        )

      refute has_element?(view, "div[id=ai_bot_collapsed]")
      refute has_element?(view, "div[id=ai_bot_conversation]")
    end

    test "collapsed button includes descriptive alt text", %{
      conn: conn,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} =
        live_isolated(
          conn,
          OliWeb.Dialogue.WindowLive,
          session: %{
            "section_slug" => section.slug,
            "current_user_id" => user.id,
            "service_config" => stub_service_config()
          }
        )

      assert has_element?(view, "img[alt='Dot AI icon']")
    end

    test "adaptive sessions expose the adaptive page context tool only in supported mode", %{
      conn: conn,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, adaptive_view, _html} =
        live_isolated(
          conn,
          OliWeb.Dialogue.WindowLive,
          session: %{
            "section_slug" => section.slug,
            "current_user_id" => user.id,
            "adaptive_delivery_view" => "adaptive_with_chrome",
            "service_config" => stub_service_config()
          }
        )

      assert function_names(adaptive_view) |> Enum.member?("adaptive_page_context")

      {:ok, standard_view, _html} =
        live_isolated(
          conn,
          OliWeb.Dialogue.WindowLive,
          session: %{
            "section_slug" => section.slug,
            "current_user_id" => user.id,
            "service_config" => stub_service_config()
          }
        )

      refute function_names(standard_view) |> Enum.member?("adaptive_page_context")
    end

    test "assistant disabled keeps the dialogue hidden", %{conn: conn, user: user} do
      section = insert(:section, assistant_enabled: false)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} =
        live_isolated(
          conn,
          OliWeb.Dialogue.WindowLive,
          session: %{"section_slug" => section.slug, "current_user_id" => user.id}
        )

      refute has_element?(view, "div[data-dialogue-window]")
    end

    test "adaptive screen change events update the current activity attempt guid and dialogue state",
         %{
           conn: conn,
           user: user,
           section: section
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} =
        live_isolated(
          conn,
          OliWeb.Dialogue.WindowLive,
          session: %{
            "section_slug" => section.slug,
            "current_user_id" => user.id,
            "adaptive_delivery_view" => "adaptive_with_chrome",
            "service_config" => stub_service_config()
          }
        )

      render_hook(view, "adaptive_screen_changed", %{"activity_attempt_guid" => "attempt-guid-1"})

      assert socket_assigns(view).current_activity_attempt_guid == "attempt-guid-1"

      remembered_message =
        dialogue_state(view).messages
        |> Enum.find(&(&1.name == "adaptive_runtime_update"))

      assert remembered_message.role == :system
      assert remembered_message.content =~ "attempt-guid-1"
      assert remembered_message.content =~ "adaptive_page_context"
    end

    test "adaptive screen change keeps only the latest runtime update in dialogue state", %{
      conn: conn,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} =
        live_isolated(
          conn,
          OliWeb.Dialogue.WindowLive,
          session: %{
            "section_slug" => section.slug,
            "current_user_id" => user.id,
            "adaptive_delivery_view" => "adaptive_with_chrome",
            "service_config" => stub_service_config()
          }
        )

      render_hook(view, "adaptive_screen_changed", %{"activity_attempt_guid" => "attempt-guid-1"})
      render_hook(view, "adaptive_screen_changed", %{"activity_attempt_guid" => "attempt-guid-2"})

      runtime_updates =
        dialogue_state(view).messages
        |> Enum.filter(&(&1.name == "adaptive_runtime_update"))

      assert length(runtime_updates) == 1
      assert hd(runtime_updates).content =~ "attempt-guid-2"
    end
  end

  defp function_names(view) do
    dialogue_state(view).configuration.functions
    |> Enum.map(& &1.name)
  end

  defp dialogue_state(view) do
    dialogue_pid = socket_assigns(view).dialogue
    :sys.get_state(dialogue_pid)
  end

  defp socket_assigns(view) do
    :sys.get_state(view.pid).socket.assigns
  end

  defp stub_service_config do
    %ServiceConfig{id: 1, name: "test-service-config", primary_model: %{id: 1}}
  end
end
