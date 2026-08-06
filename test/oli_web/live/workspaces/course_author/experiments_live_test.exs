defmodule OliWeb.Workspaces.CourseAuthor.ExperimentsLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Authoring.Experiments
  alias Oli.Experiments.Schemas.ExperimentDefinition
  alias Oli.Resources.{Resource, ResourceType, Revision}
  alias Oli.Repo

  defp live_view_experiments_route(project_slug, params \\ %{}),
    do: ~p"/workspaces/course_author/#{project_slug}/experiments?#{params}"

  defp experiment_id(view) do
    [_, id] = Regex.run(~r{/experiments/(\d+)}, render(view))

    id
  end

  defp put_view(context) do
    {:ok, view, _html} = live(context.conn, live_view_experiments_route(context.project.slug))
    [view: view]
  end

  defp create_project(_conn) do
    insert(:institution)
    create_project_fixture()
  end

  defp create_project_without_institution(_conn) do
    create_project_fixture()
  end

  defp create_project_fixture do
    project = insert(:project, experiments_enabled: true)
    container_resource = insert(:resource)

    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        objectives: %{},
        resource_type_id: ResourceType.id_for_container(),
        children: [],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    publication =
      insert(:publication, %{
        project: project,
        published: nil,
        root_resource_id: container_resource.id
      })

    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision
    })

    [project: project, publication: publication]
  end

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the experiments view", %{
      conn: conn
    } do
      project = insert(:project)

      redirect_path = "/authors/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_experiments_route(project.slug))
    end
  end

  describe "user cannot access when is logged in as a student" do
    setup [:user_conn, :create_project]

    test "redirects to new session when accessing the experiments view", %{
      conn: conn,
      project: project
    } do
      redirect_path = "/authors/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_experiments_route(project.slug))
    end
  end

  describe "user cannot access when is logged in as an instructor" do
    setup [:instructor_conn, :create_project]

    test "redirects to new session when accessing the experiments view", %{
      conn: conn,
      project: project
    } do
      redirect_path = "/authors/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_experiments_route(project.slug))
    end
  end

  describe "experiments view" do
    setup [:admin_conn, :create_project, :put_view]

    test "loads experiments view correctly", %{view: view} do
      {view, %{}}
      |> step(:test_has_title_AB_testing)
      |> step(:test_has_message_integrate_with_AB_platform)

      refute has_element?(view, "#ab-experiments-toggle-form")
    end

    test "decision points and conditions are editable without export controls", %{
      view: _view,
      conn: conn,
      project: project,
      publication: publication
    } do
      legacy_experiment = insert_legacy_experiment(publication)

      # Reloads page
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))

      {view,
       %{
         resource_id: legacy_experiment.resource_id,
         options: legacy_experiment.content["options"]
       }}
      |> step(:test_has_alternatives_group)
      |> step(:test_has_options)
      |> step(:put_options)
      |> step(:test_has_button_show_edit_group_modal)
      |> step(:test_has_button_show_edit_option_1_modal)
      |> step(:test_has_button_show_edit_option_2_modal)
      |> step(:test_has_button_show_delete_option_1_modal)
      |> step(:test_has_button_show_delete_option_2_modal)
      |> step(:test_has_new_condition_action)
      |> step(:test_has_button_download_segment_json, :refute)
      |> step(:test_has_button_download_experiment_json, :refute)
    end

    test "reorders decision point conditions and uses the alternatives delete button style", %{
      view: _view,
      conn: conn,
      admin: admin,
      project: project,
      publication: publication
    } do
      decision_point = insert_legacy_experiment(publication, admin)
      {:ok, view, html} = live(conn, live_view_experiments_route(project.slug))

      assert has_element?(
               view,
               "button.btn.btn-danger[phx-click='show_delete_decision_point_modal'][phx-value-resource-id='#{decision_point.resource_id}']",
               "Delete"
             )

      assert_before(html, "Option 1", "Option 2")

      assert has_element?(
               view,
               "#alternatives-option-#{decision_point.resource_id}-option_1[phx-hook='DragSource'][draggable='true'][tabindex='0'][phx-keydown='keyboard_reorder_option'][aria-keyshortcuts*='Shift+ArrowUp']"
             )

      refute has_element?(view, "#keyboard-reorder-#{decision_point.resource_id}-option_1")

      refute has_element?(view, "button[aria-label^='Move Option']")

      assert has_element?(
               view,
               "#alternatives-option-actions-#{decision_point.resource_id}-option_1 button[aria-label='Options'][aria-expanded='false'][aria-controls='dropdownMenu_#{decision_point.resource_id}_option_1']"
             )

      assert has_element?(
               view,
               "#alternatives-option-#{decision_point.resource_id}-option_1-reorder-position:not([aria-live])",
               "Item position 1 of 2."
             )

      assert has_element?(
               view,
               "#alternatives-reorder-status-#{decision_point.resource_id}[aria-live='polite'][aria-atomic='true']"
             )

      view
      |> element("#alternatives-option-#{decision_point.resource_id}-option_1")
      |> render_keydown(%{"key" => "ArrowDown", "shiftKey" => true})

      assert_before(render(view), "Option 2", "Option 1")

      render_hook(view, "reorder_option", %{
        "resourceId" => decision_point.resource_id,
        "optionId" => "option_2",
        "dropIndex" => 0
      })

      assert_before(render(view), "Option 2", "Option 1")

      reordered = Experiments.get_latest_experiment(project.slug).content["options"]
      assert Enum.map(reordered, & &1["id"]) == ["option_2", "option_1"]

      render_hook(view, "reorder_option", %{
        "resourceId" => decision_point.resource_id,
        "optionId" => "option_2",
        "dropIndex" => 2
      })

      assert_before(render(view), "Option 1", "Option 2")
    end

    test "creates decision points in the experiments view", %{view: view, project: project} do
      assert has_element?(view, "button", "New Decision Point")

      view
      |> element("button", "New Decision Point")
      |> render_click()

      view
      |> form("#create_decision_point_modal form", %{
        "params" => %{"name" => "Homepage Decision"}
      })
      |> render_submit()

      assert has_element?(view, ".alternatives-group", "Homepage Decision")

      open_create_experiment(view)
      assert has_element?(view, "#experiment_decision_point option", "Homepage Decision")

      revision = Experiments.get_latest_experiment(project.slug)
      assert revision.title == "Homepage Decision"
      assert revision.content["strategy"] == "upgrade_decision_point"
    end

    test "sorts decision points by creation date ascending and renders the create action below them",
         %{
           view: _view,
           conn: conn,
           admin: admin,
           project: project,
           publication: publication
         } do
      first = insert_legacy_experiment(publication, admin, "Created Later")
      second = insert_legacy_experiment(publication, admin, "Created Earlier")

      first.resource_id
      |> then(&Repo.get!(Resource, &1))
      |> Ecto.Changeset.change(inserted_at: ~U[2026-01-02 00:00:00Z])
      |> Repo.update!()

      second.resource_id
      |> then(&Repo.get!(Resource, &1))
      |> Ecto.Changeset.change(inserted_at: ~U[2026-01-01 00:00:00Z])
      |> Repo.update!()

      {:ok, view, html} = live(conn, live_view_experiments_route(project.slug))

      {first_position, _} = :binary.match(html, "Created Earlier")
      {second_position, _} = :binary.match(html, "Created Later")
      {button_position, _} = :binary.match(html, "New Decision Point")

      assert first_position < second_position
      assert second_position < button_position
      assert has_element?(view, "button[phx-click='show_create_decision_point']")
    end

    test "creates and cancels a condition inline", %{
      view: _view,
      conn: conn,
      admin: admin,
      project: project,
      publication: publication
    } do
      decision_point = insert_legacy_experiment(publication, admin)
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))
      form_id = "#new-condition-form-#{decision_point.resource_id}"
      input_id = "#new-condition-input-#{decision_point.resource_id}"

      refute has_element?(view, input_id)

      view
      |> element(
        "button[phx-click='show_new_condition_form'][phx-value-resource-id='#{decision_point.resource_id}']",
        "New Condition"
      )
      |> render_click()

      assert has_element?(
               view,
               "#{input_id}[placeholder='Enter a new condition'][phx-hook='InputAutoSelect']"
             )

      assert has_element?(
               view,
               "#{form_id} label[for='new-condition-input-#{decision_point.resource_id}']",
               "Condition name"
             )

      assert has_element?(view, "#{form_id} button", "Cancel")
      assert has_element?(view, "#{form_id} button[type='submit'][disabled]", "Create")

      view
      |> form(form_id, %{
        "condition" => %{
          "resource_id" => decision_point.resource_id,
          "name" => "Condition 3"
        }
      })
      |> render_change()

      assert has_element?(view, "#{form_id} button", "Cancel")
      assert has_element?(view, "#{form_id} button[type='submit']:not([disabled])", "Create")

      view
      |> form(form_id, %{
        "condition" => %{
          "resource_id" => decision_point.resource_id,
          "name" => "Condition 3"
        }
      })
      |> render_submit()

      assert has_element?(view, ".alternatives-group", "Condition 3")
      refute has_element?(view, "#{form_id} button", "Create")
      refute has_element?(view, input_id)

      view
      |> element(
        "button[phx-click='show_new_condition_form'][phx-value-resource-id='#{decision_point.resource_id}']",
        "New Condition"
      )
      |> render_click()

      view
      |> form(form_id, %{
        "condition" => %{
          "resource_id" => decision_point.resource_id,
          "name" => "Cancelled condition"
        }
      })
      |> render_change()

      view
      |> element(input_id)
      |> render_keydown(%{"key" => "Escape"})

      refute has_element?(view, "#{form_id} button", "Create")
      refute has_element?(view, input_id)
      assert has_element?(view, "button", "New Condition")
      refute render(view) =~ "Cancelled condition"
    end

    test "deletes a decision point after confirmation", %{
      view: _view,
      conn: conn,
      admin: admin,
      project: project,
      publication: publication
    } do
      decision_point = insert_legacy_experiment(publication, admin)
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))

      view
      |> element(
        "button[phx-click='show_delete_decision_point_modal'][phx-value-resource-id='#{decision_point.resource_id}']"
      )
      |> render_click()

      assert has_element?(
               view,
               "#delete_decision_point_modal",
               "Are you sure you want to delete this decision point?"
             )

      assert has_element?(
               view,
               "#delete_decision_point_modal [role='dialog'][aria-modal='true']"
             )

      view
      |> element("#delete_decision_point_modal button", "Delete")
      |> render_click()

      refute has_element?(view, ".alternatives-group", decision_point.title)
    end

    test "uses the shared modal for deleting a condition", %{
      view: _view,
      conn: conn,
      admin: admin,
      project: project,
      publication: publication
    } do
      decision_point = insert_legacy_experiment(publication, admin)
      [condition | _] = decision_point.content["options"]
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))

      view
      |> element(
        "button[phx-click='show_delete_option_modal'][phx-value-option-id='#{condition["id"]}']"
      )
      |> render_click()

      assert has_element?(
               view,
               "#delete_condition_modal [role='dialog'][aria-modal='true']"
             )

      assert has_element?(view, "#delete_condition_modal", condition["name"])

      view
      |> element("#delete_condition_modal button", "Cancel")
      |> render_click()

      refute has_element?(view, "#delete_condition_modal")
    end

    test "blocks deletion for active experiments and allows it for archived experiments", %{
      view: _view,
      conn: conn,
      admin: admin,
      project: project
    } do
      decision_point = insert_alternatives_group(project, admin)
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))
      open_create_experiment(view)

      view
      |> element("#create-ab-experiment-form")
      |> render_submit(%{
        "experiment" => %{
          "name" => "Protected Decision Point",
          "slug" => "protected_decision_point",
          "algorithm" => "weighted_random",
          "decision_point" => decision_point.resource_id,
          "weight_a" => "1",
          "weight_b" => "1"
        }
      })

      view
      |> element(
        "button[phx-click='show_delete_decision_point_modal'][phx-value-resource-id='#{decision_point.resource_id}']"
      )
      |> render_click()

      refute has_element?(view, "#delete_decision_point_modal")

      assert render(view) =~
               "This decision point cannot be deleted because it is used by an active experiment"

      assert has_element?(view, ".alternatives-group", decision_point.title)

      ExperimentDefinition
      |> Oli.Repo.get_by!(slug: "protected_decision_point")
      |> Ecto.Changeset.change(state: :archived)
      |> Oli.Repo.update!()

      view
      |> element(
        "button[phx-click='show_delete_decision_point_modal'][phx-value-resource-id='#{decision_point.resource_id}']"
      )
      |> render_click()

      assert has_element?(view, "#delete_decision_point_modal")

      view
      |> element("#delete_decision_point_modal button", "Delete")
      |> render_click()

      refute has_element?(view, ".alternatives-group", decision_point.title)
    end

    test "download buttons remain absent", %{view: view} do
      {view, %{}}
      |> step(:test_has_button_download_segment_json, :refute)
      |> step(:test_has_button_download_experiment_json, :refute)
    end

    test "renders header", %{view: view} do
      assert view
             |> element("#header_id")
             |> render() =~
               "Experiments"
    end

    test "suggests and applies a unique slug from the experiment name", %{
      conn: conn,
      project: project
    } do
      insert_alternatives_group(project)
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))
      open_create_experiment(view)

      view
      |> element("#create-ab-experiment-form")
      |> render_change(%{
        "experiment" => %{
          "name" => "Suggested Study",
          "algorithm" => "weighted_random"
        }
      })

      suggestion =
        view
        |> element("#use-suggested-experiment-slug")
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.text()
        |> String.trim()

      assert suggestion == "suggested_study"

      assert has_element?(
               view,
               "button#use-suggested-experiment-slug[type='button'][phx-click='use_suggested_experiment_slug']"
             )

      view
      |> element("#use-suggested-experiment-slug")
      |> render_click()

      assert has_element?(view, "#experiment_slug[value='suggested_study']")

      view
      |> element("#create-ab-experiment-form")
      |> render_submit(%{
        "experiment" => %{
          "name" => "Suggested Study",
          "slug" => suggestion,
          "algorithm" => "weighted_random",
          "decision_point" => selected_decision_point_value(view),
          "weight_a" => "1",
          "weight_b" => "1"
        }
      })

      open_create_experiment(view)

      view
      |> element("#create-ab-experiment-form")
      |> render_change(%{
        "experiment" => %{
          "name" => "Suggested Study",
          "algorithm" => "weighted_random"
        }
      })

      unique_suggestion =
        view
        |> element("#use-suggested-experiment-slug")
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.text()
        |> String.trim()

      assert unique_suggestion != suggestion
      assert String.starts_with?(unique_suggestion, "suggested_study_")
    end

    test "creates and starts a weighted random A/B Testing experiment", %{
      conn: conn,
      project: project
    } do
      insert_alternatives_group(project)
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))

      refute render(view) =~ "Coming soon"
      refute has_element?(view, "a", "Download Experiment JSON")
      assert has_element?(view, "#show-archived-experiments")
      refute has_element?(view, "#show-archived-experiments[checked]")

      open_create_experiment(view)

      assert has_element?(
               view,
               "#create-experiment-modal [role='dialog'][aria-modal='true']"
             )

      assert has_element?(
               view,
               "#create-ab-experiment-form > .form-group:first-child label",
               "Assignment Policy"
             )

      assert has_element?(view, "#create-ab-experiment-form button", "Cancel")
      assert has_element?(view, "#create-ab-experiment-form button[type='submit']", "Create")
      refute has_element?(view, "#create-experiment-sections")

      view
      |> element("#create-ab-experiment-form")
      |> render_submit(%{
        "experiment" => %{
          "name" => "Homepage Study",
          "slug" => "homepage-study",
          "algorithm" => "weighted_random",
          "decision_point" => selected_decision_point_value(view),
          "weight_a" => "2",
          "weight_b" => "1",
          "prior_alpha" => "1",
          "prior_beta" => "1",
          "warm_up_assignments" => "0",
          "max_condition_share" => "1"
        }
      })

      assert has_element?(view, "#ab-experiments-table", "Homepage Study")
      assert has_element?(view, "#ab-experiments-table", "Weighted random")
      assert has_element?(view, "#ab-experiments-table", "Draft")
      refute has_element?(view, "#ab-experiments-table th", "Actions")
      refute has_element?(view, "#ab-experiments-table button")

      id = experiment_id(view)
      details_path = ~p"/workspaces/course_author/#{project.slug}/experiments/#{id}"
      {:ok, details_view, _html} = live(conn, details_path)

      details_view
      |> element("button[phx-click='start_experiment']", "Start")
      |> render_click()

      assert has_element?(details_view, "#experiment-configuration", "Active")

      refute has_element?(
               details_view,
               "button[phx-click='request_experiment_transition'][phx-value-action='archive']",
               "Archive"
             )

      details_view
      |> element(
        "button[phx-click='request_experiment_transition'][phx-value-action='complete']",
        "Complete"
      )
      |> render_click()

      assert has_element?(
               details_view,
               "#confirm-experiment-transition-modal [role='dialog']",
               "Complete “Homepage Study”?"
             )

      details_view
      |> element("#confirm-experiment-transition-modal button", "Complete")
      |> render_click()

      assert has_element?(details_view, "#experiment-configuration", "Completed")

      details_view
      |> element(
        "button[phx-click='request_experiment_transition'][phx-value-action='archive']",
        "Archive"
      )
      |> render_click()

      assert has_element?(
               details_view,
               "#confirm-experiment-transition-modal [role='dialog']",
               "Archive “Homepage Study”?"
             )

      details_view
      |> element("#confirm-experiment-transition-modal button", "Archive")
      |> render_click()

      assert has_element?(details_view, "#experiment-configuration", "Archived")

      {:ok, archived_index_view, _html} =
        live(conn, live_view_experiments_route(project.slug))

      refute has_element?(archived_index_view, "#ab-experiments-table", "Homepage Study")

      archived_index_view
      |> element("#show-archived-experiments")
      |> render_click()

      assert has_element?(archived_index_view, "#show-archived-experiments[checked]")
      assert has_element?(archived_index_view, "#ab-experiments-table", "Homepage Study")
      assert has_element?(archived_index_view, "#ab-experiments-table", "Archived")
    end

    test "configuration page shows details and paginates editable participating sections", %{
      conn: conn,
      project: project,
      publication: publication
    } do
      insert_alternatives_group(project)
      {:ok, index_view, _html} = live(conn, live_view_experiments_route(project.slug))
      open_create_experiment(index_view)

      index_view
      |> element("#create-ab-experiment-form")
      |> render_submit(%{
        "experiment" => %{
          "name" => "Configuration Study",
          "slug" => "configuration-study",
          "algorithm" => "weighted_random",
          "decision_point" => selected_decision_point_value(index_view),
          "weight_a" => "1",
          "weight_b" => "1"
        }
      })

      id = experiment_id(index_view)
      institution = insert(:institution)

      sections =
        for ordinal <- 1..11 do
          section =
            insert(:section,
              institution: institution,
              base_project: project,
              title: "Eligible Section #{ordinal}"
            )

          insert(:section_project_publication,
            section: section,
            project: project,
            publication: publication
          )

          section
        end

      path = ~p"/workspaces/course_author/#{project.slug}/experiments/#{id}"
      {:ok, details_view, _html} = live(conn, path)

      assert has_element?(details_view, "#experiment-configuration h2", "Configuration Study")
      assert has_element?(details_view, "#experiment-details-heading", "Experiment details")
      assert has_element?(details_view, "#experiment-configuration", "Weighted random")
      assert has_element?(details_view, "#experiment-conditions-table th", "Option ID")
      assert has_element?(details_view, "#experiment-conditions-table td", "A")
      assert has_element?(details_view, "#experiment-conditions-table td", "B")
      assert has_element?(details_view, "#experiment-conditions-table td", "alt-a")

      assert has_element?(
               details_view,
               "#participating-sections-table-scroll.overflow-x-auto > #participating-sections-table"
             )

      assert has_element?(
               details_view,
               "a[href^='/workspaces/course_author/#{project.slug}/experiments?'] [class*='font-semibold']",
               "Experiments"
             )

      assert has_element?(details_view, "#participating-section-#{Enum.at(sections, 0).id}")
      assert has_element?(details_view, "#participating-section-#{Enum.at(sections, 9).id}")
      refute has_element?(details_view, "#participating-section-#{Enum.at(sections, 10).id}")
      refute has_element?(details_view, "#participating-sections-table th", "Participating")

      assert has_element?(
               details_view,
               "#participating-section-#{Enum.at(sections, 0).id} a[href='/sections/#{Enum.at(sections, 0).slug}/manage']",
               Enum.at(sections, 0).title
             )

      assert has_element?(details_view, "nav[aria-label='Participating sections pages']")

      assert has_element?(
               details_view,
               "span#participating-sections-previous[aria-disabled='true']"
             )

      refute has_element?(details_view, "a#participating-sections-previous")
      assert has_element?(details_view, "a#participating-sections-next[href*='page=2']")

      first_section = hd(sections)

      details_view
      |> element("#participating-section-#{first_section.id} input[type='checkbox']")
      |> render_click()

      assert has_element?(
               details_view,
               "#participating-section-#{first_section.id} input[type='checkbox'][checked]"
             )

      {:ok, page_two_view, _html} = live(conn, "#{path}?page=2")

      assert has_element?(page_two_view, "#participating-section-#{Enum.at(sections, 10).id}")
      refute has_element?(page_two_view, "#participating-section-#{Enum.at(sections, 0).id}")
      assert has_element?(page_two_view, "a#participating-sections-previous[href*='page=1']")
      assert has_element?(page_two_view, "span#participating-sections-next[aria-disabled='true']")
      refute has_element?(page_two_view, "a#participating-sections-next")
    end

    test "configures accessible empty section participation and preserves explicit fallback copy",
         %{
           conn: conn,
           project: project
         } do
      insert_alternatives_group(project)
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))

      open_create_experiment(view)

      view
      |> element("#create-ab-experiment-form")
      |> render_submit(%{
        "experiment" => %{
          "name" => "Section Study",
          "slug" => "section-study",
          "algorithm" => "weighted_random",
          "decision_point" => selected_decision_point_value(view),
          "weight_a" => "1",
          "weight_b" => "1"
        }
      })

      id = experiment_id(view)

      view
      |> element("#ab-experiments-table a", "Section Study")
      |> render_click()

      assert_redirect(
        view,
        ~p"/workspaces/course_author/#{project.slug}/experiments/#{id}"
      )

      {:ok, details_view, _html} =
        live(conn, ~p"/workspaces/course_author/#{project.slug}/experiments/#{id}")

      assert has_element?(
               details_view,
               "[role='status']",
               "No active eligible sections are available."
             )

      refute has_element?(details_view, "#participating-sections-table-scroll")
      refute has_element?(details_view, "#participating-sections-table")
    end

    test "creates and starts a Thompson Sampling A/B Testing experiment", %{
      conn: conn,
      project: project
    } do
      insert_alternatives_group(project)
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))

      open_create_experiment(view)

      assert has_element?(view, "#experiment_algorithm option", "Thompson Sampling")
      assert has_element?(view, "#experiment_weight_a[value='1']")
      assert has_element?(view, "#experiment_weight_b[value='1']")
      refute render(view) =~ "Coming soon"

      view
      |> element("#create-ab-experiment-form")
      |> render_change(%{"experiment" => %{"algorithm" => "thompson_sampling"}})

      assert has_element?(
               view,
               "#thompson-sampling-options.font-weight-bold",
               "Thompson Sampling Options"
             )

      refute has_element?(view, "#thompson-sampling-config")
      assert has_element?(view, "#experiment_prior_alpha[value='1']")
      assert has_element?(view, "#experiment_prior_beta[value='1']")
      assert has_element?(view, "#experiment_warm_up_assignments[value='0']")
      assert has_element?(view, "#experiment_max_condition_share[value='1']")

      view
      |> element("#create-ab-experiment-form")
      |> render_submit(%{
        "experiment" => %{
          "name" => "Adaptive Study",
          "slug" => "adaptive-study",
          "algorithm" => "thompson_sampling",
          "decision_point" => selected_decision_point_value(view),
          "weight_a" => "1",
          "weight_b" => "1",
          "prior_alpha" => "1",
          "prior_beta" => "1",
          "warm_up_assignments" => "0",
          "max_condition_share" => "1"
        }
      })

      assert has_element?(view, "#ab-experiments-table", "Adaptive Study")
      assert has_element?(view, "#ab-experiments-table", "Thompson Sampling")
      assert has_element?(view, "#ab-experiments-table", "Draft")

      id = experiment_id(view)

      {:ok, details_view, _html} =
        live(conn, ~p"/workspaces/course_author/#{project.slug}/experiments/#{id}")

      details_view
      |> element("button[phx-click='start_experiment']", "Start")
      |> render_click()

      assert has_element?(details_view, "#experiment-configuration", "Active")
    end

    test "shows field error for malformed Thompson Sampling numeric input", %{
      conn: conn,
      project: project
    } do
      insert_alternatives_group(project)
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))

      open_create_experiment(view)

      view
      |> element("#create-ab-experiment-form")
      |> render_submit(%{
        "experiment" => %{
          "name" => "Adaptive Study",
          "slug" => "adaptive-study",
          "algorithm" => "thompson_sampling",
          "decision_point" => selected_decision_point_value(view),
          "weight_a" => "2.5",
          "weight_b" => "3.5",
          "prior_alpha" => "1abc",
          "prior_beta" => "2.25",
          "warm_up_assignments" => "7",
          "max_condition_share" => "0.75"
        }
      })

      assert has_element?(
               view,
               "#experiment_prior_alpha_error",
               "Prior alpha must be between 0.0001 and 1000."
             )

      assert has_element?(view, "#experiment_prior_alpha.is-invalid")

      assert has_element?(
               view,
               "#create-experiment-modal #create-experiment-error[role='alert'][tabindex='-1'][phx-mounted]",
               "Prior alpha must be between 0.0001 and 1000."
             )

      refute has_element?(view, "section > .alert.alert-danger")

      assert has_element?(view, "#experiment_name[value='Adaptive Study']")
      assert has_element?(view, "#experiment_weight_a[value='2.5']")
      assert has_element?(view, "#experiment_weight_b[value='3.5']")
      assert has_element?(view, "#experiment_prior_alpha[value='1abc']")
      assert has_element?(view, "#experiment_prior_beta[value='2.25']")
      assert has_element?(view, "#experiment_warm_up_assignments[value='7']")
      assert has_element?(view, "#experiment_max_condition_share[value='0.75']")
    end

    test "preserves empty numeric inputs after validation", %{conn: conn, project: project} do
      insert_alternatives_group(project)
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))

      open_create_experiment(view)

      view
      |> element("#create-ab-experiment-form")
      |> render_submit(%{
        "experiment" => %{
          "name" => "Empty Numeric Study",
          "slug" => "empty-numeric-study",
          "algorithm" => "thompson_sampling",
          "decision_point" => selected_decision_point_value(view),
          "weight_a" => "",
          "weight_b" => "",
          "prior_alpha" => "",
          "prior_beta" => "",
          "warm_up_assignments" => "",
          "max_condition_share" => ""
        }
      })

      assert has_element?(view, "#experiment_weight_a[value='']")
      assert has_element?(view, "#experiment_weight_b[value='']")
      assert has_element?(view, "#experiment_prior_alpha[value='']")
      assert has_element?(view, "#experiment_prior_beta[value='']")
      assert has_element?(view, "#experiment_warm_up_assignments[value='']")
      assert has_element?(view, "#experiment_max_condition_share[value='']")
    end

    test "preserves Thompson Sampling inputs while switching assignment policies", %{
      conn: conn,
      project: project
    } do
      insert_alternatives_group(project)
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))

      open_create_experiment(view)

      view
      |> element("#create-ab-experiment-form")
      |> render_change(%{
        "experiment" => %{
          "algorithm" => "thompson_sampling",
          "prior_alpha" => "2.5",
          "prior_beta" => "3.5",
          "warm_up_assignments" => "12",
          "max_condition_share" => "0.8"
        }
      })

      view
      |> element("#create-ab-experiment-form")
      |> render_change(%{"experiment" => %{"algorithm" => "weighted_random"}})

      refute has_element?(view, "#thompson-sampling-options")

      view
      |> element("#create-ab-experiment-form")
      |> render_change(%{"experiment" => %{"algorithm" => "thompson_sampling"}})

      assert has_element?(view, "#experiment_prior_alpha[value='2.5']")
      assert has_element?(view, "#experiment_prior_beta[value='3.5']")
      assert has_element?(view, "#experiment_warm_up_assignments[value='12']")
      assert has_element?(view, "#experiment_max_condition_share[value='0.8']")
    end

    test "does not offer learner preference alternatives as A/B Testing decision points", %{
      conn: conn,
      project: project
    } do
      insert_preference_alternatives_group(project)
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))

      assert has_element?(view, "button[disabled]", "Create Experiment")
      refute has_element?(view, "#create-ab-experiment-form")

      assert has_element?(
               view,
               "div",
               "Create an A/B decision point before adding an A/B Testing experiment."
             )
    end

    test "does not expose obsolete creation terminology or JSON workflows", %{view: view} do
      refute has_element?(view, "a", "Download Experiment JSON")
      refute has_element?(view, "a", "Download Segment JSON")
      refute render(view) =~ "upgrade_decision_point"
    end
  end

  describe "experiments view without institutions" do
    setup [:admin_conn, :create_project_without_institution]

    test "lists project decision point candidates without requiring institution scope", %{
      conn: conn,
      project: project
    } do
      insert_alternatives_group(project)

      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))

      open_create_experiment(view)

      assert has_element?(view, "#create-ab-experiment-form")
      assert has_element?(view, "#experiment_decision_point option", "Decision Point")
    end
  end

  defp insert_legacy_experiment(publication, author \\ nil, title \\ "Decision Point") do
    resource = insert(:resource)
    insert(:project_resource, project_id: publication.project_id, resource_id: resource.id)

    revision =
      insert(:revision, %{
        resource: resource,
        author: author,
        resource_type_id: ResourceType.id_for_alternatives(),
        title: title,
        content: %{
          "strategy" => "upgrade_decision_point",
          "options" => [
            %{"id" => "option_1", "name" => "Option 1"},
            %{"id" => "option_2", "name" => "Option 2"}
          ]
        }
      })

    insert(:published_resource, publication: publication, resource: resource, revision: revision)

    revision
  end

  defp insert_alternatives_group(project, author \\ nil) do
    resource = insert(:resource)
    insert(:project_resource, project_id: project.id, resource_id: resource.id)

    revision =
      insert(:revision, %{
        resource: resource,
        author: author,
        resource_type_id: ResourceType.id_for_alternatives(),
        title: "Decision Point",
        deleted: false,
        content: %{
          "strategy" => "upgrade_decision_point",
          "options" => [
            %{"id" => "alt-a", "name" => "A"},
            %{"id" => "alt-b", "name" => "B"}
          ]
        }
      })

    publication = Oli.Publishing.project_working_publication(project.slug)
    insert(:published_resource, publication: publication, resource: resource, revision: revision)
    revision
  end

  defp insert_preference_alternatives_group(project) do
    resource = insert(:resource)
    insert(:project_resource, project_id: project.id, resource_id: resource.id)

    insert(:revision, %{
      resource: resource,
      resource_type_id: ResourceType.id_for_alternatives(),
      title: "Learner Preference",
      deleted: false,
      content: %{
        "strategy" => "user_section_preference",
        "options" => [
          %{"id" => "alt-a", "name" => "A"},
          %{"id" => "alt-b", "name" => "B"}
        ]
      }
    })
  end

  defp selected_decision_point_value(view) do
    [experiment] = project_experiments(view)
    experiment.alternatives_resource_id |> to_string()
  end

  defp project_experiments(view) do
    html = render(view)

    Regex.scan(~r/<option[^>]+value="(\d+)"/, html, capture: :all_but_first)
    |> Enum.map(fn [id] -> %{alternatives_resource_id: String.to_integer(id)} end)
  end

  defp evaluate_assertion(to_evaluate, assert_or_refute) do
    case assert_or_refute do
      :assert -> assert to_evaluate
      :refute -> refute to_evaluate
    end
  end

  defp step(_view_and_ctx, _operation, assert_or_refute \\ :assert)

  defp step({view, ctx}, :test_has_button_download_experiment_json, assert_or_refute) do
    to_evaluate = has_element?(view, "a", "Download Experiment JSON")

    evaluate_assertion(to_evaluate, assert_or_refute)

    {view, ctx}
  end

  defp step({view, ctx}, :test_has_button_download_segment_json, assert_or_refute) do
    to_evaluate = has_element?(view, "a", "Download Segment JSON")

    evaluate_assertion(to_evaluate, assert_or_refute)

    {view, ctx}
  end

  defp step({view, ctx}, :test_has_alternatives_group, assert_or_refute) do
    to_evaluate = has_element?(view, ".alternatives-group", "Decision Point")
    evaluate_assertion(to_evaluate, assert_or_refute)
    {view, ctx}
  end

  defp step({view, ctx}, :test_has_button_show_edit_group_modal, assert_or_refute) do
    resource_id = Map.get(ctx, :resource_id)
    assert resource_id

    to_evaluate =
      has_element?(
        view,
        "button[phx-click='show_edit_group_modal'][phx-value-resource-id='#{resource_id}'] > .fa-pencil"
      )

    evaluate_assertion(to_evaluate, assert_or_refute)

    {view, ctx}
  end

  defp step({view, ctx}, :test_has_message_integrate_with_AB_platform, assert_or_refute) do
    target_text = "Create and manage A/B experiments in this project."
    to_evaluate = element(view, "p") |> render() =~ target_text
    evaluate_assertion(to_evaluate, assert_or_refute)
    {view, ctx}
  end

  defp step({view, ctx}, :test_has_title_AB_testing, assert_or_refute) do
    to_evaluate = has_element?(view, "#header_id", "Experiments")
    evaluate_assertion(to_evaluate, assert_or_refute)
    {view, ctx}
  end

  defp step({view, ctx}, :test_has_options, assert_or_refute) do
    to_evaluate = has_element?(view, "[id^='alternatives-options-']", "Option 1")
    evaluate_assertion(to_evaluate, assert_or_refute)
    to_evaluate = has_element?(view, "[id^='alternatives-options-']", "Option 2")
    evaluate_assertion(to_evaluate, assert_or_refute)
    to_evaluate = has_element?(view, "[id^='alternatives-options-']", "Option 3")
    evaluate_assertion(to_evaluate, :refute)

    {view, ctx}
  end

  defp step({view, ctx}, :test_has_button_show_edit_option_1_modal, assert_or_refute) do
    option_1 = Map.get(ctx, :option_1)
    assert option_1

    to_evaluate =
      has_element?(
        view,
        "button[phx-click='show_edit_option_modal'][phx-value-option-id=\"#{option_1["id"]}\"] > .fa-pencil"
      )

    evaluate_assertion(to_evaluate, assert_or_refute)

    {view, ctx}
  end

  defp step({view, ctx}, :test_has_button_show_edit_option_2_modal, assert_or_refute) do
    option_2 = Map.get(ctx, :option_2)
    assert option_2

    to_evaluate =
      has_element?(
        view,
        "button[phx-click='show_edit_option_modal'][phx-value-option-id=\"#{option_2["id"]}\"] > .fa-pencil"
      )

    evaluate_assertion(to_evaluate, assert_or_refute)
    {view, ctx}
  end

  defp step({view, ctx}, :test_has_button_show_delete_option_1_modal, assert_or_refute) do
    option_1 = Map.get(ctx, :option_1)
    assert option_1

    to_evaluate =
      has_element?(
        view,
        "button[phx-click='show_delete_option_modal'][phx-value-option-id=\"#{option_1["id"]}\"] > .fa-trash"
      )

    evaluate_assertion(to_evaluate, assert_or_refute)
    {view, ctx}
  end

  defp step({view, ctx}, :test_has_button_show_delete_option_2_modal, assert_or_refute) do
    option_2 = Map.get(ctx, :option_2)
    assert option_2

    to_evaluate =
      has_element?(
        view,
        "button[phx-click='show_delete_option_modal'][phx-value-option-id=\"#{option_2["id"]}\"] > .fa-trash"
      )

    evaluate_assertion(to_evaluate, assert_or_refute)
    {view, ctx}
  end

  defp step({view, ctx}, :test_has_new_condition_action, assert_or_refute) do
    resource_id = Map.get(ctx, :resource_id)
    assert resource_id

    to_evaluate =
      has_element?(
        view,
        "button[phx-click='show_new_condition_form'][phx-value-resource-id='#{resource_id}']",
        "New Condition"
      )

    evaluate_assertion(to_evaluate, assert_or_refute)

    {view, ctx}
  end

  defp step({view, ctx}, :test_experiment_has_2_options, _assert_or_refute) do
    resource_id = Map.get(ctx, :resource_id)
    assert resource_id

    content = Experiments.get_latest_experiment(ctx.project.slug).content
    option_names = get_in(content, ["options", Access.all(), "name"])
    assert option_names == ["Option 1", "Option 2"]

    {view, ctx}
  end

  defp step({view, ctx}, :test_experiment_has_3_options, _assert_or_refute) do
    resource_id = Map.get(ctx, :resource_id)
    assert resource_id

    content = Experiments.get_latest_experiment(ctx.project.slug).content
    option_names = get_in(content, ["options", Access.all(), "name"])
    assert option_names == ["Option 1", "Option 2", "Option 3"]

    {view, ctx}
  end

  defp step({view, ctx}, :test_duplicate_error_message, _assert_or_refute) do
    assert render(view) =~
             "The option could not be created because duplicate options have been found"

    {view, ctx}
  end

  defp step({view, ctx}, :put_options, _assert_or_refute) do
    resource_id = Map.get(ctx, :resource_id)
    assert resource_id

    [option_1, option_2] =
      Oli.Repo.get_by!(Revision, resource_id: resource_id).content["options"]

    ctx = ctx |> Map.put(:option_1, option_1) |> Map.put(:option_2, option_2)
    {view, ctx}
  end

  defp step({view, ctx}, :put_resource_id, _assert_or_refute) do
    [resource_id] =
      view
      |> element("button[phx-click='show_edit_group_modal']")
      |> render()
      |> Floki.parse_document!()
      |> Floki.find("button[phx-click='show_edit_group_modal']")
      |> Floki.attribute("phx-value-resource-id")

    {view, Map.put(ctx, :resource_id, resource_id)}
  end

  defp open_create_experiment(view) do
    view
    |> element("button[phx-click='open_create_experiment']", "Create Experiment")
    |> render_click()
  end

  defp assert_before(html, first, second) do
    {first_position, _} = :binary.match(html, first)
    {second_position, _} = :binary.match(html, second)
    assert first_position < second_position
  end
end
