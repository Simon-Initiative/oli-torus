defmodule OliWeb.Sections.AssessmentSettings.SettingsLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.{Settings, Sections}
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Resources.ResourceType
  alias Oli.Publishing.DeliveryResolver

  defp set_student_exception(section, resource, student, params \\ %{}) do
    insert(
      :delivery_setting,
      Map.merge(
        %{
          user: student,
          section: section,
          resource: resource
        },
        params
      )
    )
  end

  defp live_view_overview_route(section_slug, active_tab, assessment_id) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Sections.AssessmentSettings.SettingsLive,
      section_slug,
      active_tab,
      assessment_id
    )
  end

  defp create_project(%{user: user}) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # revisions...
    ## objectives
    objective_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("objective"),
        title: "Objective 1"
      )

    objective_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("objective"),
        title: "Objective 2"
      )

    objective_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("objective"),
        title: "Objective 3"
      )

    objective_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("objective"),
        title: "Objective 4"
      )

    ## graded pages (assessments)...
    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        objectives: %{"attached" => [objective_1_revision.resource_id]},
        title: "Page 1",
        graded: true
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        objectives: %{"attached" => [objective_2_revision.resource_id]},
        title: "Page 2",
        graded: true
      )

    page_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        objectives: %{"attached" => [objective_3_revision.resource_id]},
        title: "Page 3",
        graded: true
      )

    page_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        objectives: %{"attached" => [objective_4_revision.resource_id]},
        title: "Page 4",
        graded: true
      )

    ## modules...
    module_1_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_1_revision.resource_id, page_2_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Module 1"
      })

    module_2_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_3_revision.resource_id, page_4_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Module 2"
      })

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [module_1_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Unit 1"
      })

    unit_2_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [module_2_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Unit 2"
      })

    ## root container...
    container_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [unit_1_revision.resource_id, unit_2_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Root Container"
      })

    # asociate resources to project
    insert(:project_resource, %{
      project_id: project.id,
      resource_id: objective_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: objective_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: objective_3_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: objective_4_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_3_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_4_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: module_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: module_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: unit_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: unit_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: container_revision.resource_id
    })

    # publish project and resources
    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_revision.resource_id
      })

    insert(:published_resource, %{
      publication: publication,
      resource: objective_1_revision.resource,
      revision: objective_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: objective_2_revision.resource,
      revision: objective_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: objective_3_revision.resource,
      revision: objective_3_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: objective_4_revision.resource,
      revision: objective_4_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_1_revision.resource,
      revision: page_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_2_revision.resource,
      revision: page_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_3_revision.resource,
      revision: page_3_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_4_revision.resource,
      revision: page_4_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: module_1_revision.resource,
      revision: module_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: module_2_revision.resource,
      revision: module_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: unit_1_revision.resource,
      revision: unit_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: unit_2_revision.resource,
      revision: unit_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: container_revision.resource,
      revision: container_revision,
      author: author
    })

    # create section...
    section =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)

    # enroll students to section

    [student_1, student_2] = insert_pair(:user)
    [student_3, student_4] = insert_pair(:user)
    # instructor = insert(:user)

    Sections.enroll(student_1.id, section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    Sections.enroll(student_2.id, section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    Sections.enroll(student_3.id, section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    Sections.enroll(student_4.id, section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    Sections.enroll(user.id, section.id, [
      ContextRoles.get_role(:context_instructor)
    ])

    %{
      section: section,
      page_1: page_1_revision,
      page_2: page_2_revision,
      page_3: page_3_revision,
      page_4: page_4_revision,
      page_1_objective: objective_1_revision,
      page_2_objective: objective_2_revision,
      page_3_objective: objective_3_revision,
      page_4_objective: objective_4_revision,
      module_1: module_1_revision,
      module_2: module_2_revision,
      unit_1: unit_1_revision,
      unit_2: unit_2_revision,
      student_1: student_1,
      student_2: student_2,
      student_3: student_3,
      student_4: student_4,
      instructor: user
    }
  end

  defp create_section(_conn) do
    section = insert(:section)

    [section: section]
  end

  defp get_assessments(section_slug, student_exceptions) do
    DeliveryResolver.graded_pages_revisions_and_section_resources(section_slug)
    |> Enum.map(fn {rev, sr} ->
      Settings.combine(rev, sr, nil)
      |> Map.merge(%{
        name: rev.title,
        scheduling_type: sr.scheduling_type,
        exceptions_count:
          Enum.count(student_exceptions, fn se ->
            se.resource_id == rev.resource_id
          end)
      })
    end)
  end

  defp table_as_list_of_maps(view, tab_name) do
    keys =
      case tab_name do
        :settings ->
          [
            :name,
            :due_date,
            :max_attempts,
            :time_limit,
            :late_submit,
            :late_start,
            :scoring_strategy_id,
            :grace_period,
            :retake_mode,
            :feedback_mode,
            :review_submission,
            :exceptions_count
          ]

        :student_exceptions ->
          [
            :student,
            :due_date,
            :max_attempts,
            :time_limit,
            :late_submit,
            :late_start,
            :scoring_strategy_id,
            :grace_period,
            :retake_mode,
            :feedback_mode,
            :review_submission,
            :exceptions_count
          ]
      end

    assessments =
      view
      |> render()
      |> Floki.parse_fragment!()
      |> Floki.find(~s{.instructor_dashboard_table tbody tr})
      |> Enum.map(fn row ->
        Floki.find(row, "td")
        |> Enum.map(fn data ->
          case Floki.find(data, "select") do
            [] ->
              Floki.text(data)

            select ->
              Floki.find(select, "option[selected]")
              |> Floki.text()
          end
        end)
      end)

    Enum.map(assessments, fn a ->
      Enum.zip(keys, a)
      |> Enum.into(%{})
    end)
  end

  describe "user cannot access when is not logged in" do
    setup [:create_section]

    test "redirects to new session when accessing the settings view", %{
      conn: conn,
      section: section
    } do
      section_slug = section.slug
      active_tab = "settings"
      assessment_id = "all"

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section_slug}%2Fassessment_settings%2F#{active_tab}%2F#{assessment_id}&section=#{section_slug}"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_overview_route(section.slug, "settings", "all"))
    end

    test "redirects to new session when accessing the student_exceptions view",
         %{
           conn: conn,
           section: section
         } do
      section_slug = section.slug
      active_tab = "student_exceptions"
      assessment_id = "all"

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section_slug}%2Fassessment_settings%2F#{active_tab}%2F#{assessment_id}&section=#{section_slug}"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(
          conn,
          live_view_overview_route(section.slug, "student_exceptions", "all")
        )
    end
  end

  describe "user cannot access when is logged in as an instructor but is not enrolled in the section" do
    setup [:user_conn]

    test "redirects to new session when accessing the settings view", %{
      conn: conn
    } do
      section = insert(:section, %{type: :enrollable})

      conn = get(conn, live_view_overview_route(section.slug, "settings", "all"))

      redirect_path = "/unauthorized"
      assert redirected_to(conn, 302) =~ redirect_path
    end

    test "redirects to new session when accessing the student_exceptions view",
         %{
           conn: conn
         } do
      section = insert(:section, %{type: :enrollable})

      conn =
        get(
          conn,
          live_view_overview_route(section.slug, "student_exceptions", "all")
        )

      redirect_path = "/unauthorized"
      assert redirected_to(conn, 302) =~ redirect_path
    end
  end

  describe "user cannot access when is logged in as a student and is enrolled in the section" do
    setup [:user_conn]

    test "redirects to new session when accessing the settings view", %{
      conn: conn,
      user: user
    } do
      section = insert(:section, %{type: :enrollable})

      Sections.enroll(user.id, section.id, [
        ContextRoles.get_role(:context_learner)
      ])

      conn = get(conn, live_view_overview_route(section.slug, "settings", "all"))

      redirect_path = "/unauthorized"
      assert redirected_to(conn, 302) =~ redirect_path
    end

    test "redirects to new session when accessing the student_exceptions view",
         %{
           conn: conn,
           user: user
         } do
      section = insert(:section, %{type: :enrollable})

      Sections.enroll(user.id, section.id, [
        ContextRoles.get_role(:context_learner)
      ])

      conn =
        get(
          conn,
          live_view_overview_route(section.slug, "student_exceptions", "all")
        )

      redirect_path = "/unauthorized"
      assert redirected_to(conn, 302) =~ redirect_path
    end
  end

  describe "user can access when is logged in as an instructor and is enrolled in the section" do
    setup [:user_conn, :create_project]

    test "settings view loads correctly", %{
      conn: conn,
      section: section,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3,
      page_4: page_4
    } do
      {:ok, view, html} = live(conn, live_view_overview_route(section.slug, "settings", "all"))

      [assessment_1, assessment_2, assessment_3, assessment_4] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tbody tr})
        |> Enum.map(fn row -> Floki.text(row) |> String.split("\n") |> hd() end)

      assert view
             |> has_element?("p", "These are your current assessment settings.")

      assert assessment_1 == page_1.title
      assert assessment_2 == page_2.title
      assert assessment_3 == page_3.title
      assert assessment_4 == page_4.title

      assert html =~
               ~s(<a href="/sections/#{section.slug}/instructor_dashboard/manage">Manage Section</a>)
    end

    test "student_exceptions view loads correctly", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} =
        live(
          conn,
          live_view_overview_route(section.slug, "student_exceptions", "all")
        )

      assert view
             |> has_element?(
               "label",
               "Select an assessment to manage student specific exceptions"
             )
    end
  end

  describe "settings tab" do
    setup [:user_conn, :create_project]

    test "gets a correct exception count", %{
      conn: conn,
      section: section,
      student_1: student_1,
      student_2: student_2,
      student_3: student_3,
      student_4: student_4,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3,
      page_4: page_4
    } do
      set_student_exception(section, page_1.resource, student_1)
      set_student_exception(section, page_1.resource, student_2)
      set_student_exception(section, page_1.resource, student_3)
      set_student_exception(section, page_1.resource, student_4)

      set_student_exception(section, page_2.resource, student_1)
      set_student_exception(section, page_2.resource, student_2)
      set_student_exception(section, page_2.resource, student_3)

      set_student_exception(section, page_3.resource, student_1)
      set_student_exception(section, page_3.resource, student_2)

      set_student_exception(section, page_4.resource, student_1)

      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug, "settings", "all"))

      [assessment_1, assessment_2, assessment_3, assessment_4] =
        table_as_list_of_maps(view, :settings)

      assert assessment_1.exceptions_count =~ "4"
      assert assessment_2.exceptions_count =~ "3"
      assert assessment_3.exceptions_count =~ "2"
      assert assessment_4.exceptions_count =~ "1"
    end

    test "exception count links to corresponding student exceptions for that assessment",
         %{
           conn: conn,
           section: section,
           student_1: student_1,
           page_1: page_1
         } do
      set_student_exception(section, page_1.resource, student_1)

      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug, "settings", "all"))

      {:error, {:live_redirect, %{kind: :push, to: url}}} =
        element(
          view,
          ".instructor_dashboard_table tbody tr:first-of-type td:last-of-type a",
          "1"
        )
        |> render_click()

      assert url ==
               Routes.live_path(
                 OliWeb.Endpoint,
                 OliWeb.Sections.AssessmentSettings.SettingsLive,
                 section.slug,
                 :student_exceptions,
                 page_1.resource.id
               )
    end

    test "changing an assessment setting updates that record on the DB and on the UI",
         %{
           conn: conn,
           section: section,
           page_1: page_1
         } do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug, "settings", "all"))

      page_1_assessment_settings =
        get_assessments(section.slug, [])
        |> Enum.find(fn assessment ->
          assessment.resource_id == page_1.resource.id
        end)

      assert page_1_assessment_settings.late_submit == :allow

      view
      |> form(~s{form[for="settings_table"]})
      |> render_change(%{
        "_target" => ["late_submit-#{page_1.resource.id}"],
        "late_submit-#{page_1.resource.id}" => "disallow"
      })

      updated_page_1_assessment_settings =
        get_assessments(section.slug, [])
        |> Enum.find(fn assessment ->
          assessment.resource_id == page_1.resource.id
        end)

      assert view
             |> has_element?("div .alert-info", "Setting updated!")

      assert updated_page_1_assessment_settings.late_submit == :disallow
    end

    test "clicking on bulk apply button shows the confirm modal for the selected assessment",
         %{
           conn: conn,
           section: section,
           page_2: page_2
         } do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug, "settings", "all"))

      refute element(view, "#confirm_bulk_apply_modal")
             |> has_element?()

      view
      |> form(~s{form[for="bulk_apply_settings"]})
      |> render_submit(%{"assessment_id" => page_2.resource.id})

      assert element(view, "#confirm_bulk_apply_modal")
             |> has_element?()

      assert element(view, "#confirm_bulk_apply_modal")
             |> render() =~
               "<p>Are you sure you want to apply the <strong>Page 2</strong> settings to all other assessments?</p>"
    end

    test "confirming the bulk apply modal applies the selected setting to all other assessments",
         %{
           conn: conn,
           section: section,
           page_3: page_3
         } do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug, "settings", "all"))

      [assessment_1, assessment_2, assessment_3, assessment_4] =
        table_as_list_of_maps(view, :settings)

      assert assessment_1.late_submit == "Allow"
      assert assessment_2.late_submit == "Allow"
      assert assessment_3.late_submit == "Allow"
      assert assessment_4.late_submit == "Allow"

      # we change page 3 late submit setting to :disallow
      view
      |> form(~s{form[for="settings_table"]})
      |> render_change(%{
        "_target" => ["late_submit-#{page_3.resource.id}"],
        "late_submit-#{page_3.resource.id}" => "disallow"
      })

      # and bulk apply that change to all other assessments
      view
      |> form(~s{form[for="bulk_apply_settings"]})
      |> render_submit(%{"assessment_id" => page_3.resource.id})

      view
      |> form(~s{form[phx-submit=confirm_bulk_apply]})
      |> render_submit(%{})
      |> follow_redirect(
        conn,
        "/sections/#{section.slug}/assessment_settings/settings/all?limit=10&offset=0&sort_by=name&sort_order=asc&text_search="
      )

      # after being redirected, we validate all changes were applied
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug, "settings", "all"))

      [assessment_1, assessment_2, assessment_3, assessment_4] =
        table_as_list_of_maps(view, :settings)

      assert assessment_1.late_submit == "Disallow"
      assert assessment_2.late_submit == "Disallow"
      assert assessment_3.late_submit == "Disallow"
      assert assessment_4.late_submit == "Disallow"

      assert Enum.uniq([
               Map.drop(assessment_1, [:name]),
               Map.drop(assessment_2, [:name]),
               Map.drop(assessment_3, [:name]),
               Map.drop(assessment_4, [:name])
             ])
             |> length() == 1
    end

    test "cancelling the bulk apply modal hides the modal without changing any setting",
         %{
           conn: conn,
           section: section,
           page_3: page_3
         } do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug, "settings", "all"))

      [
        initial_assessment_1,
        initial_assessment_2,
        initial_assessment_3,
        initial_assessment_4
      ] = table_as_list_of_maps(view, :settings)

      # open bulk apply modal for page 3
      view
      |> form(~s{form[for="bulk_apply_settings"]})
      |> render_submit(%{"assessment_id" => page_3.resource.id})

      assert element(view, "#confirm_bulk_apply_modal")
             |> has_element?()

      # click the cancel button
      view
      |> element("button[id=cancel_bulk_apply_button]")
      |> render_click()

      refute element(view, "#confirm_bulk_apply_modal")
             |> has_element?()

      [
        final_assessment_1,
        final_assessment_2,
        final_assessment_3,
        final_assessment_4
      ] = table_as_list_of_maps(view, :settings)

      assert initial_assessment_1 == final_assessment_1
      assert initial_assessment_2 == final_assessment_2
      assert initial_assessment_3 == final_assessment_3
      assert initial_assessment_4 == final_assessment_4
    end

    test "search input filters assessments by the provided text input",
         %{
           conn: conn,
           section: section
         } do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug, "settings", "all"))

      view
      |> form(~s{form[for="search"]})
      |> render_change(%{"assessment_name" => "Page 3"})

      assessments = table_as_list_of_maps(view, :settings)

      assert length(assessments) == 1
      assert hd(assessments).name == "Page 3"
    end

    test "can be sorted",
         %{
           conn: conn,
           section: section,
           page_3: page_3
         } do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug, "settings", "all"))

      [initial_a1, initial_a2, initial_a3, initial_a4] = table_as_list_of_maps(view, :settings)

      view
      |> element("th[phx-value-sort_by=name]")
      |> render_click()

      [sorted_1, sorted_2, sorted_3, sorted_4] = table_as_list_of_maps(view, :settings)

      assert initial_a4 == sorted_1
      assert initial_a3 == sorted_2
      assert initial_a2 == sorted_3
      assert initial_a1 == sorted_4

      # change page 3 late_submit value to "disallow" and then sort by that column
      view
      |> form(~s{form[for="settings_table"]})
      |> render_change(%{
        "_target" => ["late_submit-#{page_3.resource.id}"],
        "late_submit-#{page_3.resource.id}" => "disallow"
      })

      view
      |> element("th[phx-value-sort_by=late_submit]")
      |> render_click()

      [sorted_1, sorted_2, sorted_3, sorted_4] = table_as_list_of_maps(view, :settings)

      assert initial_a3.name == sorted_1.name
      assert sorted_1.late_submit == "Disallow"
      assert sorted_2.late_submit == "Allow"
      assert sorted_3.late_submit == "Allow"
      assert sorted_4.late_submit == "Allow"
    end

    test "changing a value of a setting of the column used for sorting does not trigger the re-sorting",
         %{
           conn: conn,
           section: section,
           page_1: page_1,
           page_2: page_2,
           page_3: page_3,
           page_4: page_4
         } do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug, "settings", "all"))

      # sort by late_submit
      view
      |> element("th[phx-value-sort_by=late_submit]")
      |> render_click()

      [sorted_1, sorted_2, sorted_3, sorted_4] = table_as_list_of_maps(view, :settings)

      # change the late_submit value of the second listed assessment
      second_listed_page =
        Enum.find([page_1, page_2, page_3, page_4], fn page ->
          page.title == sorted_2.name
        end)

      view
      |> form(~s{form[for="settings_table"]})
      |> render_change(%{
        "_target" => ["late_submit-#{second_listed_page.resource.id}"],
        "late_submit-#{second_listed_page.resource.id}" => "disallow"
      })

      [assessment_1, assessment_2, assessment_3, assessment_4] =
        table_as_list_of_maps(view, :settings)

      assert sorted_1 == assessment_1
      assert sorted_2.name == assessment_2.name
      assert assessment_2.late_submit == "Disallow"
      assert sorted_3 == assessment_3
      assert sorted_4 == assessment_4
    end

    test "if feedback_mode value is set to :scheduled a model is shown to set the scheduled date",
         %{
           conn: conn,
           section: section,
           page_1: page_1
         } do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug, "settings", "all"))

      page_1_assessment_settings =
        get_assessments(section.slug, [])
        |> Enum.find(fn assessment ->
          assessment.resource_id == page_1.resource.id
        end)

      assert page_1_assessment_settings.feedback_mode == :allow
      assert page_1_assessment_settings.feedback_scheduled_date == nil

      refute has_element?(view, "div[id=scheduled_modal]")

      view
      |> form(~s{form[for="settings_table"]})
      |> render_change(%{
        "_target" => ["feedback_mode-#{page_1.resource.id}"],
        "feedback_mode-#{page_1.resource.id}" => "scheduled"
      })

      assert has_element?(view, "div[id=scheduled_modal]")
    end

    test "an error is shown if the scheduled modal is confirmed without providing a scheduled date",
         %{
           conn: conn,
           section: section,
           page_1: page_1
         } do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug, "settings", "all"))

      page_1_assessment_settings =
        get_assessments(section.slug, [])
        |> Enum.find(fn assessment ->
          assessment.resource_id == page_1.resource.id
        end)

      assert page_1_assessment_settings.feedback_mode == :allow
      assert page_1_assessment_settings.feedback_scheduled_date == nil

      view
      |> form(~s{form[for="settings_table"]})
      |> render_change(%{
        "_target" => ["feedback_mode-#{page_1.resource.id}"],
        "feedback_mode-#{page_1.resource.id}" => "scheduled"
      })

      view
      |> form(~s{form[phx-submit=submit_scheduled_date]})
      |> render_submit()

      assert has_element?(
               view,
               ~s{form[phx-submit=submit_scheduled_date] span},
               "can't be blank"
             )
    end

    test "a scheduled date is set when the modal is confirmed and updated in the UI",
         %{
           conn: conn,
           section: section,
           page_1: page_1
         } do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug, "settings", "all"))

      page_1_assessment_settings =
        get_assessments(section.slug, [])
        |> Enum.find(fn assessment ->
          assessment.resource_id == page_1.resource.id
        end)

      assert page_1_assessment_settings.feedback_mode == :allow
      assert page_1_assessment_settings.feedback_scheduled_date == nil

      view
      |> form(~s{form[for="settings_table"]})
      |> render_change(%{
        "_target" => ["feedback_mode-#{page_1.resource.id}"],
        "feedback_mode-#{page_1.resource.id}" => "scheduled"
      })

      view
      |> form(~s{form[phx-submit=submit_scheduled_date]})
      |> render_submit(%{
        "section_resource" => %{
          "feedback_scheduled_date" => "2023-05-29T21:50"
        }
      })

      page_1_assessment_settings =
        get_assessments(section.slug, [])
        |> Enum.find(fn assessment ->
          assessment.resource_id == page_1.resource.id
        end)

      [ass_1, _ass_2, _ass_3, _ass_4] = table_as_list_of_maps(view, :settings)

      assert ass_1.feedback_mode == "Scheduled"
      assert page_1_assessment_settings.feedback_mode == :scheduled

      assert page_1_assessment_settings.feedback_scheduled_date ==
               ~U[2023-05-29 21:50:00Z]
    end

    test "feedback_mode value is not set to :scheduled when the modal is cancelled and the modal closes",
         %{
           conn: conn,
           section: section,
           page_1: page_1
         } do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug, "settings", "all"))

      page_1_assessment_settings =
        get_assessments(section.slug, [])
        |> Enum.find(fn assessment ->
          assessment.resource_id == page_1.resource.id
        end)

      assert page_1_assessment_settings.feedback_mode == :allow
      assert page_1_assessment_settings.feedback_scheduled_date == nil

      view
      |> form(~s{form[for="settings_table"]})
      |> render_change(%{
        "_target" => ["feedback_mode-#{page_1.resource.id}"],
        "feedback_mode-#{page_1.resource.id}" => "scheduled"
      })

      assert has_element?(view, "div[id=scheduled_modal]")

      view
      |> element(~s{button[id=scheduled_cancel_button]})
      |> render_click()

      refute has_element?(view, "div[id=scheduled_modal]")

      page_1_assessment_settings =
        get_assessments(section.slug, [])
        |> Enum.find(fn assessment ->
          assessment.resource_id == page_1.resource.id
        end)

      assert page_1_assessment_settings.feedback_mode == :allow
      assert page_1_assessment_settings.feedback_scheduled_date == nil
    end

    test "schedule date can be changed by clicking the due date in the table",
         %{
           conn: conn,
           section: section,
           page_1: page_1
         } do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug, "settings", "all"))

      # LiveViewTest doesn't support testing two or more JS.push chained so I need to trigger two events separatedly
      view
      |> with_target("#settings_table")
      |> render_click("edit_date", %{assessment_id: "#{page_1.resource_id}"})

      view
      |> with_target("#assessment_due_date_modal")
      |> render_click("open", %{})

      assert has_element?(view, "h5", "Page 1 due date")
      assert has_element?(view, "label", "Please pick a due date for the selected assessment")

      new_date = ~U[2023-10-10 16:00:00Z]

      view
      |> element("#assessment-due-date-form")
      |> render_submit(%{end_date: new_date})

      assert has_element?(view, "button", "October 10, 2023")
    end
  end

  describe "student exceptions tab" do
    setup [:user_conn, :create_project]

    test "user can filter by assessment",
         %{
           conn: conn,
           section: section,
           page_1: page_1,
           page_2: page_2,
           page_3: page_3,
           student_1: student_1,
           student_2: student_2
         } do
      set_student_exception(section, page_1.resource, student_1)
      set_student_exception(section, page_1.resource, student_2)
      set_student_exception(section, page_2.resource, student_1)

      {:ok, view, _html} =
        live(
          conn,
          live_view_overview_route(section.slug, "student_exceptions", "all")
        )

      # select assessment 1
      view
      |> form(~s{form[id=assessment_select]})
      |> render_change(%{"assessments" => %{"assessment_id" => page_1.resource.id}})

      assert [se_1, se_2] = table_as_list_of_maps(view, :student_exceptions)
      assert se_1.student =~ student_1.name
      assert se_2.student =~ student_2.name
      refute render(view) =~ "None exist"

      # select assessment 2
      view
      |> form(~s{form[id=assessment_select]})
      |> render_change(%{"assessments" => %{"assessment_id" => page_2.resource.id}})

      assert [se_1] = table_as_list_of_maps(view, :student_exceptions)
      assert se_1.student =~ student_1.name
      refute render(view) =~ "None exist"

      # select assessment 3
      view
      |> form(~s{form[id=assessment_select]})
      |> render_change(%{"assessments" => %{"assessment_id" => page_3.resource.id}})

      assert [] = table_as_list_of_maps(view, :student_exceptions)
      assert render(view) =~ "None exist"
    end

    test "the remove button is disbled if no student exception is selected", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} =
        live(
          conn,
          live_view_overview_route(section.slug, "student_exceptions", "all")
        )

      assert has_element?(
               view,
               ~s{button[phx-click=show_modal][disabled=disabled]},
               "Remove Selected"
             )
    end

    test "a student exception can be removed", %{
      conn: conn,
      section: section,
      page_1: page_1,
      student_1: student_1
    } do
      set_student_exception(section, page_1.resource, student_1)

      {:ok, view, _html} =
        live(
          conn,
          live_view_overview_route(
            section.slug,
            "student_exceptions",
            page_1.resource.id
          )
        )

      [student_exception] = table_as_list_of_maps(view, :student_exceptions)

      assert student_exception.student =~ student_1.name

      # check the student exception
      view
      |> form(~s{form[for="student_exceptions_table"]})
      |> render_change(%{
        "_target" => ["checkbox-#{student_1.id}"],
        "checkbox-#{student_1.id}" => "on"
      })

      # click the remove button (that has been enabled)
      view
      |> element(
        ~s{button[phx-click=show_modal]},
        "Remove Selected"
      )
      |> render_click()

      # the confirm modal is shown
      assert has_element?(view, ~s{div[id=confirm_removal_modal]})

      assert element(view, ~s{div[id=confirm_removal_modal]})
             |> render() =~
               "Are you sure you want to remove the selected exceptions?"

      # user confirms removal
      view
      |> form(~s{form[phx-submit=remove_student_exceptions]})
      |> render_submit()

      # a flash message confirms the removal and the exception is not listed anymore
      assert has_element?(
               view,
               ~s{div.alert.alert-info},
               "Student Exception/s removed!"
             )

      assert table_as_list_of_maps(view, :student_exceptions) == []
      assert render(view) =~ "None exist"
    end

    test "a student exception is not removed if the confirm modal is cancelled",
         %{
           conn: conn,
           section: section,
           page_1: page_1,
           student_1: student_1
         } do
      set_student_exception(section, page_1.resource, student_1)

      {:ok, view, _html} =
        live(
          conn,
          live_view_overview_route(
            section.slug,
            "student_exceptions",
            page_1.resource.id
          )
        )

      [initial_student_exception] = table_as_list_of_maps(view, :student_exceptions)

      # check the student exception
      view
      |> form(~s{form[for="student_exceptions_table"]})
      |> render_change(%{
        "_target" => ["checkbox-#{student_1.id}"],
        "checkbox-#{student_1.id}" => "on"
      })

      # click the remove button (that has been enabled)
      view
      |> element(
        ~s{button[phx-click=show_modal]},
        "Remove Selected"
      )
      |> render_click()

      # the confirm modal is shown
      assert has_element?(view, ~s{div[id=confirm_removal_modal]})

      assert element(view, ~s{div[id=confirm_removal_modal]})
             |> render() =~
               "Are you sure you want to remove the selected exceptions?"

      # user cancels removal
      view
      |> element(~s{button[id=cancel_removal_button]})
      |> render_click()

      # modal is hidden and the student exception is still listed
      [listed_student_exception] = table_as_list_of_maps(view, :student_exceptions)

      refute has_element?(view, ~s{div[id=confirm_removal_modal]})
      assert initial_student_exception == listed_student_exception
    end

    test "a student exception can be added",
         %{
           conn: conn,
           section: section,
           page_1: page_1,
           student_1: student_1
         } do
      {:ok, view, _html} =
        live(
          conn,
          live_view_overview_route(
            section.slug,
            "student_exceptions",
            page_1.resource.id
          )
        )

      assert [] = table_as_list_of_maps(view, :student_exceptions)
      assert render(view) =~ "None exist"

      view
      |> element(~s{button[phx-value-modal_name=add_student_exception]}, "Add New")
      |> render_click()

      # the modal is shown
      assert has_element?(view, ~s{div[id="add_student_exception_modal"]})

      # student one is selected and the form is submitted
      view
      |> form(~s{form[phx-submit=add_student_exception]})
      |> render_submit(%{"student_exception" => %{"student_id" => student_1.id}})

      assert [se_1] = table_as_list_of_maps(view, :student_exceptions)
      assert se_1.student =~ student_1.name
      refute render(view) =~ "None exist"
    end

    test "the add button is disabled if all students already have an exception for the given assessment",
         %{
           conn: conn,
           section: section,
           page_1: page_1,
           student_1: student_1,
           student_2: student_2,
           student_3: student_3,
           student_4: student_4
         } do
      set_student_exception(section, page_1.resource, student_1)
      set_student_exception(section, page_1.resource, student_2)
      set_student_exception(section, page_1.resource, student_3)
      set_student_exception(section, page_1.resource, student_4)

      {:ok, view, _html} =
        live(
          conn,
          live_view_overview_route(
            section.slug,
            "student_exceptions",
            page_1.resource.id
          )
        )

      assert has_element?(
               view,
               ~s{button[disabled=disabled][phx-value-modal_name=add_student_exception]},
               "Add New"
             )
    end

    test "a student exception value can be set",
         %{
           conn: conn,
           section: section,
           page_1: page_1,
           student_1: student_1
         } do
      set_student_exception(section, page_1.resource, student_1)

      {:ok, view, _html} =
        live(
          conn,
          live_view_overview_route(
            section.slug,
            "student_exceptions",
            page_1.resource.id
          )
        )

      [student_exception_1] = table_as_list_of_maps(view, :student_exceptions)

      assert student_exception_1.late_submit == "-"

      view
      |> form(~s{form[for="student_exceptions_table"]})
      |> render_change(%{
        "_target" => ["late_submit-#{student_1.id}"],
        "late_submit-#{student_1.id}" => "disallow"
      })

      [updated_student_exception_1] = table_as_list_of_maps(view, :student_exceptions)
      assert updated_student_exception_1.late_submit == "Disallow"
      assert student_exception_1.student == updated_student_exception_1.student
    end

    test "the current exceptions count works correctly",
         %{
           conn: conn,
           section: section,
           page_1: page_1,
           student_1: student_1,
           student_2: student_2
         } do
      set_student_exception(section, page_1.resource, student_1)
      set_student_exception(section, page_1.resource, student_2)

      {:ok, view, _html} =
        live(
          conn,
          live_view_overview_route(
            section.slug,
            "student_exceptions",
            page_1.resource.id
          )
        )

      assert has_element?(
               view,
               "p",
               "Current exceptions: 2 students, 0 exceptions"
             )

      # set an exception for student 1
      view
      |> form(~s{form[for="student_exceptions_table"]})
      |> render_change(%{
        "_target" => ["late_submit-#{student_1.id}"],
        "late_submit-#{student_1.id}" => "disallow"
      })

      assert has_element?(
               view,
               "p",
               "Current exceptions: 2 students, 1 exception"
             )

      # set an exception for student 2
      view
      |> form(~s{form[for="student_exceptions_table"]})
      |> render_change(%{
        "_target" => ["late_submit-#{student_2.id}"],
        "late_submit-#{student_2.id}" => "disallow"
      })

      assert has_element?(
               view,
               "p",
               "Current exceptions: 2 students, 2 exceptions"
             )
    end

    test "schedule date can be changed by clicking the due date in the table",
         %{
           conn: conn,
           section: section,
           page_1: page_1,
           student_1: student_1
         } do
      exception = set_student_exception(section, page_1.resource, student_1)

      {:ok, view, _html} =
        live(
          conn,
          live_view_overview_route(
            section.slug,
            "student_exceptions",
            page_1.resource.id
          )
        )

      # LiveViewTest doesn't support testing two or more JS.push chained so I need to trigger two events separatedly
      view
      |> with_target("#student_exceptions_table")
      |> render_click("edit_date", %{user_id: "#{exception.user_id}"})

      view
      |> with_target("#student_due_date_modal")
      |> render_click("open", %{})

      assert has_element?(view, "h5", "Due date for #{student_1.name}")
      assert has_element?(view, "label", "Please pick a due date for the selected student")

      new_date = ~U[2023-10-10 16:00:00Z]

      view
      |> element("#student-due-date-form")
      |> render_submit(%{end_date: new_date})

      assert has_element?(view, "button", "October 10, 2023")
    end
  end
end
