defmodule Oli.Plugs.MaybeGatedResourceTest do
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Gating
  alias Oli.Delivery.Attempts.Core
  alias Lti_1p3.Roles.ContextRoles

  describe "maybe_gated_resource plug" do
    setup [:user_conn, :create_elixir_project, :enroll_student_and_mark_section_visited]

    test "allows section overview access for student", %{
      conn: conn,
      section: section
    } do
      stub_current_time(~U[2023-11-04 20:00:00Z])

      conn =
        conn
        |> get(~p"/sections/#{section.slug}")

      assert html_response(conn, 200) =~ section.title
    end

    test "allows access to gated resource with an open gating condition", %{
      conn: conn,
      graded_adaptive_page: graded_adaptive_page,
      section: section,
      user: user
    } do
      _first_attempt_in_progress =
        create_attempt(user, section, graded_adaptive_page, %{lifecycle_state: :active})

      _gating_condition =
        gating_condition_fixture(%{
          section_id: section.id,
          resource_id: graded_adaptive_page.resource_id,
          data: %{start_datetime: yesterday(), end_datetime: tomorrow()}
        })

      {:ok, section} = Gating.update_resource_gating_index(section)

      conn =
        conn
        |> get(~p"/sections/#{section.slug}/adaptive_lesson/#{graded_adaptive_page.slug}")

      assert html_response(conn, 200) =~ "Graded Adaptive Page"
    end

    test "blocks access to gated resource with a closed gating condition", %{
      conn: conn,
      graded_adaptive_page: graded_adaptive_page,
      section: section
    } do
      _gating_condition =
        gating_condition_fixture(%{
          section_id: section.id,
          resource_id: graded_adaptive_page.resource_id,
          data: %{end_datetime: yesterday()}
        })

      {:ok, section} = Gating.update_resource_gating_index(section)

      conn =
        conn
        |> get(~p"/sections/#{section.slug}/adaptive_lesson/#{graded_adaptive_page.slug}")

      # since this graded page has no active attempts, the user will be first redirected to the prologue page
      # from ~p"/sections/#{section.slug}/adaptive_lesson/#{graded_adaptive_page.slug}" to ~p"/sections/#{section.slug}/prologue/#{graded_adaptive_page.slug}"
      # and the prologue page will handle the blocking gates warning

      assert html_response(conn, 302) =~
               ~p"/sections/#{section.slug}/prologue/#{graded_adaptive_page.slug}"
    end

    test "blocks access to gated graded resource when :allows_nothing is in a closed gating condition",
         %{
           conn: conn,
           graded_adaptive_page: graded_adaptive_page,
           user: user,
           section: section
         } do
      _gating_condition =
        gating_condition_fixture(%{
          graded_resource_policy: :allows_nothing,
          section_id: section.id,
          resource_id: graded_adaptive_page.resource_id,
          data: %{end_datetime: yesterday()}
        })

      _first_attempt_in_progress =
        create_attempt(user, section, graded_adaptive_page, %{lifecycle_state: :active})

      {:ok, section} = Gating.update_resource_gating_index(section)

      conn =
        conn
        |> get(~p"/sections/#{section.slug}/adaptive_lesson/#{graded_adaptive_page.slug}")

      assert html_response(conn, 403) =~
               "You are trying to access a resource that is gated by the following condition"

      assert html_response(conn, 403) =~
               "#{graded_adaptive_page.title} is scheduled to end"
    end

    test "blocks access to gated graded resource with :allows_nothing policy and attempts present",
         %{
           conn: conn,
           graded_adaptive_page: graded_adaptive_page,
           user: user,
           section: section
         } do
      _first_attempt_in_progress =
        create_attempt(user, section, graded_adaptive_page, %{lifecycle_state: :active})

      _gating_condition =
        gating_condition_fixture(%{
          graded_resource_policy: :allows_nothing,
          section_id: section.id,
          resource_id: graded_adaptive_page.resource_id,
          data: %{end_datetime: yesterday()}
        })

      {:ok, section} = Gating.update_resource_gating_index(section)

      conn =
        conn
        |> get(~p"/sections/#{section.slug}/adaptive_lesson/#{graded_adaptive_page.slug}")

      assert html_response(conn, 403) =~
               "You are trying to access a resource that is gated by the following condition"

      assert html_response(conn, 403) =~
               "#{graded_adaptive_page.title} is scheduled to end"
    end

    test "blocks access to gated graded resource with :allows_review policy and no attempts present",
         %{
           conn: conn,
           graded_adaptive_page: graded_adaptive_page,
           section: section
         } do
      _gating_condition =
        gating_condition_fixture(%{
          graded_resource_policy: :allows_review,
          section_id: section.id,
          resource_id: graded_adaptive_page.resource_id,
          data: %{end_datetime: yesterday()}
        })

      {:ok, section} = Gating.update_resource_gating_index(section)

      conn =
        conn
        |> get(~p"/sections/#{section.slug}/adaptive_lesson/#{graded_adaptive_page.slug}")

      # since this graded page has no attempts, the user will be first redirected to the prologue page
      # from ~p"/sections/#{section.slug}/lesson/#{revision.slug}" to ~p"/sections/#{section.slug}/prologue/#{revision.slug}"
      # and the prologue page will handle the blocking gates warning

      assert html_response(conn, 302) =~
               ~p"/sections/#{section.slug}/prologue/#{graded_adaptive_page.slug}"
    end

    test "allows student to resume an active attempt with :allows_review policy and active attempt present",
         %{
           conn: conn,
           graded_adaptive_page: graded_adaptive_page,
           user: user,
           section: section
         } do
      _first_attempt_in_progress =
        create_attempt(user, section, graded_adaptive_page, %{lifecycle_state: :active})

      _gating_condition =
        gating_condition_fixture(%{
          graded_resource_policy: :allows_review,
          section_id: section.id,
          resource_id: graded_adaptive_page.resource_id,
          data: %{end_datetime: yesterday()}
        })

      {:ok, section} = Gating.update_resource_gating_index(section)

      conn =
        conn
        |> get(~p"/sections/#{section.slug}/adaptive_lesson/#{graded_adaptive_page.slug}")

      assert html_response(conn, 200) =~ "Graded Adaptive Page"
    end
  end

  defp create_attempt(student, section, revision, resource_attempt_data) do
    resource_access = get_or_insert_resource_access(student, section, revision)

    resource_attempt =
      insert(:resource_attempt, %{
        resource_access: resource_access,
        revision: revision,
        date_submitted: resource_attempt_data[:date_submitted] || ~U[2023-11-14 20:00:00Z],
        date_evaluated: resource_attempt_data[:date_evaluated] || ~U[2023-11-14 20:30:00Z],
        score: resource_attempt_data[:score] || 5,
        out_of: resource_attempt_data[:out_of] || 10,
        lifecycle_state: resource_attempt_data[:lifecycle_state] || :submitted,
        content: resource_attempt_data[:content] || %{model: []}
      })

    resource_attempt
  end

  defp get_or_insert_resource_access(student, section, revision) do
    Oli.Repo.get_by(
      ResourceAccess,
      resource_id: revision.resource_id,
      section_id: section.id,
      user_id: student.id
    )
    |> case do
      nil ->
        insert(:resource_access, %{
          user: student,
          section: section,
          resource: revision.resource
        })

      resource_access ->
        resource_access
    end
  end

  defp create_elixir_project(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # revisions...

    ## pages...

    exploration_1_revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        title: "Exploration 1",
        purpose: :application,
        graded: false,
        content: %{
          "model" => [],
          "advancedDelivery" => true,
          "displayApplicationChrome" => false,
          "additionalStylesheets" => [
            "/css/delivery_adaptive_themes_default_light.css"
          ]
        }
      )

    graded_adaptive_page_revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        graded: true,
        max_attempts: 5,
        title: "Graded Adaptive Page",
        purpose: :foundation,
        content: %{
          "model" => [],
          "advancedDelivery" => true,
          "displayApplicationChrome" => false,
          "additionalStylesheets" => [
            "/css/delivery_adaptive_themes_default_light.css"
          ]
        }
      )

    ## modules...
    module_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [graded_adaptive_page_revision.resource_id, exploration_1_revision.resource_id],
        title: "How to use this course"
      })

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [module_1_revision.resource_id],
        title: "Introduction"
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
        exploration_1_revision,
        graded_adaptive_page_revision,
        module_1_revision,
        unit_1_revision,
        container_revision
      ]

    # associate resources to project
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
        title: "The best course ever!",
        start_date: ~U[2023-10-30 20:00:00Z],
        analytics_version: :v2,
        assistant_enabled: true
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)

    # schedule start and end date for unit 1 section resource
    Sections.get_section_resource(section.id, unit_1_revision.resource_id)
    |> Sections.update_section_resource(%{
      start_date: ~U[2023-10-31 20:00:00Z],
      end_date: ~U[2023-12-31 20:00:00Z]
    })

    %{
      section: section,
      project: project,
      publication: publication,
      exploration_1: exploration_1_revision,
      graded_adaptive_page: graded_adaptive_page_revision,
      module_1: module_1_revision,
      unit_1: unit_1_revision
    }
  end

  defp enroll_student_and_mark_section_visited(%{user: user, section: section} = ctx) do
    Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
    ensure_user_visit(user, section)

    ctx
  end
end
