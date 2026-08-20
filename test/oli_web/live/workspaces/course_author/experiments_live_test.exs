defmodule OliWeb.Workspaces.CourseAuthor.ExperimentsLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Authoring.Experiments
  alias Oli.Experiments.Schemas.{Condition, ExperimentDefinition}
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
               "#alternatives-option-actions-#{decision_point.resource_id}-option_1 button[aria-label='Options for Option 1'][aria-expanded='false'][aria-controls='dropdownMenu_#{decision_point.resource_id}_option_1']"
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
      assert has_element?(view, "#experiment_alternatives_resource option", "Homepage Decision")

      revision = Experiments.get_latest_experiment(project.slug)
      assert revision.title == "Homepage Decision"
      assert revision.content["strategy"] == "experiment_controlled"
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
      assert has_element?(view, "button[phx-click='show_create_experiment_alternatives']")
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

    test "dismissed condition errors stay dismissed after subsequent actions", %{
      view: _view,
      conn: conn,
      admin: admin,
      project: project,
      publication: publication
    } do
      decision_point = insert_legacy_experiment(publication, admin)
      [first_condition, second_condition] = decision_point.content["options"]
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))

      view
      |> element(
        "button[phx-click='show_edit_option_modal'][phx-value-option-id='#{first_condition["id"]}']"
      )
      |> render_click()

      view
      |> form("#edit_modal-form", %{
        "params" => %{
          "id" => first_condition["id"],
          "resource_id" => decision_point.resource_id,
          "name" => second_condition["name"]
        }
      })
      |> render_submit()

      error_message = "duplicate options have been found"
      assert has_element?(view, ".alert-danger", error_message)

      view
      |> element(".alert-danger button[phx-click='lv:clear-flash'][phx-value-key='error']")
      |> render_click()

      view
      |> element("#show-archived-experiments")
      |> render_click()

      refute has_element?(view, ".alert-danger", error_message)
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
               "Are you sure you want to delete this Decision Point?"
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
          "alternatives_resource_id" => decision_point.resource_id,
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
               "This Decision Point cannot be deleted because it is used by an active experiment"

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
          "alternatives_resource_id" => selected_decision_point_value(view),
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

    test "keeps the create modal open and renders an inline error for a duplicate slug", %{
      conn: conn,
      project: project
    } do
      group = insert_alternatives_group(project)

      %ExperimentDefinition{}
      |> ExperimentDefinition.changeset(%{
        project_id: project.id,
        slug: "duplicate-experiment",
        name: "Original Experiment",
        state: :archived,
        assignment_unit: :enrollment,
        algorithm: :weighted_random,
        alternatives_resource_id: group.resource_id
      })
      |> Repo.insert!()

      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))

      open_create_experiment(view)

      view
      |> element("#create-ab-experiment-form")
      |> render_submit(%{
        "experiment" => %{
          "name" => "Duplicate Experiment",
          "slug" => "duplicate-experiment",
          "algorithm" => "weighted_random",
          "alternatives_resource_id" => selected_decision_point_value(view),
          "weight_a" => "1",
          "weight_b" => "1"
        }
      })

      assert has_element?(view, "#create-experiment-modal")
      assert has_element?(view, "#experiment_name[value='Duplicate Experiment']")
      assert has_element?(view, "#experiment_slug[value='duplicate-experiment'].is-invalid")

      assert has_element?(
               view,
               "#experiment_slug_error.text-sm.text-red-600.mb-2",
               "An experiment with this slug already exists in this project."
             )

      refute has_element?(view, "#create-experiment-error")
      assert has_element?(view, "#experiment_slug[aria-describedby='experiment_slug_error']")

      view
      |> element("#create-ab-experiment-form")
      |> render_change(%{"experiment" => %{"slug" => "available-experiment"}})

      refute has_element?(view, "#experiment_slug_error")
      refute has_element?(view, "#create-experiment-error")
    end

    test "renders an inline length error without mislabeling a long slug as a duplicate", %{
      conn: conn,
      project: project
    } do
      insert_alternatives_group(project)
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))
      open_create_experiment(view)
      slug = String.duplicate("a", 256)

      view
      |> element("#create-ab-experiment-form")
      |> render_submit(%{
        "experiment" => %{
          "name" => "Long Slug Experiment",
          "slug" => slug,
          "algorithm" => "weighted_random",
          "alternatives_resource_id" => selected_decision_point_value(view),
          "weight_a" => "1",
          "weight_b" => "1"
        }
      })

      assert has_element?(view, "#create-experiment-modal")

      assert has_element?(
               view,
               "#experiment_slug_error",
               "Slug should be at most 255 character(s)."
             )

      refute render(view) =~ "already exists"
    end

    test "creates and starts a weighted random A/B Testing experiment", %{
      conn: conn,
      project: project
    } do
      _group = insert_alternatives_group(project)
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
          "alternatives_resource_id" => selected_decision_point_value(view)
        }
      })

      assert has_element?(view, "#ab-experiments-table", "Homepage Study")
      assert has_element?(view, "#ab-experiments-table-scroll.overflow-x-auto > table")
      assert has_element?(view, "#ab-experiments-table", "Weighted random")
      assert has_element?(view, "#ab-experiments-table", "Draft")
      refute has_element?(view, "#ab-experiments-table th", "Actions")
      refute has_element?(view, "#ab-experiments-table button")

      id = experiment_id(view)
      details_path = ~p"/workspaces/course_author/#{project.slug}/experiments/#{id}"
      {:ok, details_view, _html} = live(conn, details_path)

      assert has_element?(details_view, "#condition-0-weight[value='1.0']")
      assert has_element?(details_view, "#condition-1-weight[value='1.0']")

      refute has_element?(details_view, "button", "Add intervention")
      refute has_element?(details_view, "#experiment-policy-configuration", "Scored page")

      details_view
      |> element("button[phx-click='start_experiment']", "Start")
      |> render_click()

      assert has_element?(details_view, "#experiment-configuration", "Active")
      assert has_element?(details_view, "#experiment-status-detail .badge-primary", "Active")
      refute has_element?(details_view, "#experiment-policy-report")
      assert has_element?(details_view, "#condition-0-label[disabled]")
      assert has_element?(details_view, "#condition-0-option[disabled]")
      refute has_element?(details_view, "#condition-0-weight[disabled]")
      refute has_element?(details_view, "#condition-0-active[disabled]")

      condition = Repo.get_by!(Condition, experiment_id: id, position: 0)

      details_view
      |> element("#experiment-configuration-form")
      |> render_change(%{
        "configuration" => %{"conditions" => %{"0" => %{"weight" => "3.0"}}}
      })

      assert Repo.get!(Condition, condition.id).weight == 1.0

      details_view
      |> form("#experiment-configuration-form")
      |> render_submit(%{"configuration" => %{}})

      assert Repo.get!(Condition, condition.id).weight == 3.0

      details_view
      |> element("button[phx-click='pause_experiment']", "Pause")
      |> render_click()

      assert has_element?(details_view, "#experiment-configuration", "Paused")
      assert has_element?(details_view, "button[phx-click='start_experiment']", "Resume")
      refute has_element?(details_view, "#condition-0-weight[disabled]")

      details_view
      |> element("button[phx-click='start_experiment']", "Resume")
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

      assert has_element?(
               archived_index_view,
               "#ab-experiments-empty-state",
               "No A/B Testing experiments to display"
             )

      archived_index_view
      |> element("#show-archived-experiments")
      |> render_click()

      assert has_element?(archived_index_view, "#show-archived-experiments[checked]")
      assert has_element?(archived_index_view, "#ab-experiments-table", "Homepage Study")
      assert has_element?(archived_index_view, "#ab-experiments-table", "Archived")
    end

    test "configures weighted-random assignment scope and shows UUID in details", %{
      conn: conn,
      project: project
    } do
      insert_alternatives_group(project)
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))
      open_create_experiment(view)

      refute has_element?(view, "#experiment-assignment-scope")
      refute has_element?(view, "[name='experiment[assignment_scope]']")

      view
      |> element("#create-ab-experiment-form")
      |> render_submit(%{
        "experiment" => %{
          "name" => "Scoped Study",
          "slug" => "scoped-study",
          "algorithm" => "weighted_random",
          "alternatives_resource_id" => selected_decision_point_value(view)
        }
      })

      experiment = Repo.get_by!(ExperimentDefinition, slug: "scoped-study")
      assert experiment.assignment_scope == :section_enrollment

      {:ok, details_view, _html} =
        live(
          conn,
          ~p"/workspaces/course_author/#{project.slug}/experiments/#{experiment.id}"
        )

      assert has_element?(details_view, "#experiment-details-grid", "Experiment UUID")
      assert has_element?(details_view, "#experiment-details-grid", experiment.uuid)

      assert has_element?(
               details_view,
               "#experiment-details-grid.flex.flex-wrap.gap-x-12.gap-y-8"
             )

      assert has_element?(
               details_view,
               "#experiment-details-grid > [class~='sm:flex-[1_0_12rem]']"
             )

      assert has_element?(details_view, "#experiment-details-grid .whitespace-nowrap", "Slug")

      assert has_element?(
               details_view,
               "#experiment-uuid-detail.overflow-hidden.px-4[class~='sm:flex-none']"
             )

      assert has_element?(
               details_view,
               "#experiment-uuid-detail .whitespace-nowrap",
               experiment.uuid
             )

      refute has_element?(details_view, "#experiment-details-grid", "Assignment unit")
      refute has_element?(details_view, "#experiment-details-grid", "Assignment scope")

      assert has_element?(
               details_view,
               "#configuration_assignment_scope_section_enrollment[checked]:not([disabled])"
             )

      assert has_element?(
               details_view,
               "#experiment-assignment-scope legend",
               "Condition Assignment Scope"
             )

      assert has_element?(
               details_view,
               "button#experiment-assignment-scope-help[type='button'][phx-hook='GlobalTooltip'][data-tooltip*='keeps the same condition across all interventions'][class*='focus-visible:ring-2']"
             )

      assert has_element?(
               details_view,
               "label[for='condition-0-weight'] span#condition-0-weight-help[role='img']"
             )

      refute has_element?(
               details_view,
               "label[for='condition-0-weight'] button#condition-0-weight-help"
             )

      refute has_element?(details_view, "#experiment-assignment-scope > p")
      refute has_element?(details_view, "#experiment-assignment-scope.border")
      refute has_element?(details_view, "#experiment-assignment-scope label.text-gray-500")

      render_submit(details_view, "save_configuration", %{
        "configuration" => %{"assignment_scope" => "invalid"}
      })

      assert has_element?(
               details_view,
               "#experiment-assignment-scope[aria-invalid='true'][aria-describedby*='experiment-assignment-scope-error']"
             )

      assert has_element?(
               details_view,
               "#experiment-assignment-scope-error.dark\\:text-red-400",
               "is invalid"
             )

      refute has_element?(
               details_view,
               "#experiment-configuration-card > .card-body > [role='alert']"
             )

      details_view
      |> form("#experiment-configuration-form", %{
        "configuration" => %{"assignment_scope" => "intervention"}
      })
      |> render_change()

      assert has_element?(details_view, "#configuration_assignment_scope_intervention[checked]")

      details_view
      |> form("#experiment-configuration-form")
      |> render_submit()

      assert Repo.get!(ExperimentDefinition, experiment.id).assignment_scope == :intervention

      details_view
      |> element("button[phx-click='start_experiment']", "Start")
      |> render_click()

      assert has_element?(
               details_view,
               "#configuration_assignment_scope_intervention[checked][disabled]"
             )

      assert has_element?(
               details_view,
               "#experiment-assignment-scope label.text-gray-500.cursor-not-allowed"
             )

      assert has_element?(
               details_view,
               "#experiment-assignment-scope input.disabled\\:opacity-50[disabled]"
             )

      refute has_element?(
               details_view,
               "#experiment-details-grid",
               "Independent at each intervention"
             )
    end

    test "keeps Thompson Sampling intervention-scoped and ignores forged create scope", %{
      conn: conn,
      project: project
    } do
      insert_alternatives_group(project)
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))
      open_create_experiment(view)

      view
      |> element("#create-ab-experiment-form")
      |> render_change(%{"experiment" => %{"algorithm" => "thompson_sampling"}})

      refute has_element?(view, "#experiment-assignment-scope")

      render_submit(view, "create_experiment", %{
        "experiment" => %{
          "name" => "Invalid Adaptive Scope",
          "slug" => "invalid-adaptive-scope",
          "algorithm" => "thompson_sampling",
          "assignment_scope" => "section_enrollment",
          "alternatives_resource_id" => selected_decision_point_value(view)
        }
      })

      refute has_element?(view, "#create-experiment-modal")

      assert Repo.get_by!(ExperimentDefinition, slug: "invalid-adaptive-scope").assignment_scope ==
               :intervention
    end

    test "archives a draft experiment without starting it", %{conn: conn, project: project} do
      insert_alternatives_group(project)
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))

      open_create_experiment(view)

      view
      |> element("#create-ab-experiment-form")
      |> render_submit(%{
        "experiment" => %{
          "name" => "Unused Draft",
          "slug" => "unused-draft",
          "algorithm" => "weighted_random",
          "alternatives_resource_id" => selected_decision_point_value(view)
        }
      })

      details_path =
        ~p"/workspaces/course_author/#{project.slug}/experiments/#{experiment_id(view)}"

      {:ok, details_view, _html} = live(conn, details_path)

      assert has_element?(details_view, "#experiment-configuration", "Draft")

      details_view
      |> element(
        "button[phx-click='request_experiment_transition'][phx-value-action='archive']",
        "Archive"
      )
      |> render_click()

      assert has_element?(
               details_view,
               "#confirm-experiment-transition-modal [role='dialog']",
               "Archive “Unused Draft”?"
             )

      details_view
      |> element("#confirm-experiment-transition-modal button", "Archive")
      |> render_click()

      assert has_element?(details_view, "#experiment-configuration", "Archived")
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
          "alternatives_resource_id" => selected_decision_point_value(index_view),
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
              title: "Eligible Section #{ordinal}",
              start_date: ~U[2026-08-06 00:00:00Z],
              end_date: ~U[2026-09-07 00:00:00Z]
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
      assert has_element?(details_view, "h4", "Conditions")
      assert has_element?(details_view, "input[id^='condition-'][id$='-code'][disabled]")
      refute has_element?(details_view, "input[id^='condition-'][id$='-code'][readonly]")

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
      assert has_element?(details_view, "#participating-sections-table td", "Aug 6, 2026")
      assert has_element?(details_view, "#participating-sections-table td", "Sep 7, 2026")
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

      experiment = Repo.get!(ExperimentDefinition, String.to_integer(id))

      experiment
      |> Ecto.Changeset.change(state: :completed)
      |> Repo.update!()

      {:ok, completed_view, _html} = live(conn, path)

      assert has_element?(
               completed_view,
               "#participating-sections-table input[type='checkbox'][disabled][aria-disabled='true']"
             )

      experiment
      |> Ecto.Changeset.change(state: :archived)
      |> Repo.update!()

      {:ok, archived_view, _html} = live(conn, path)

      assert has_element?(
               archived_view,
               "#participating-sections-table input[type='checkbox'][disabled][aria-disabled='true']"
             )
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
          "alternatives_resource_id" => selected_decision_point_value(view),
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
      group = insert_alternatives_group(project)
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))

      open_create_experiment(view)

      assert has_element?(view, "#experiment_algorithm option", "Thompson Sampling")
      refute has_element?(view, "#experiment_weight_a")
      refute has_element?(view, "#experiment_weight_b")
      refute has_element?(view, "#experiment_prior_alpha")
      refute has_element?(view, "#experiment_prior_beta")
      refute has_element?(view, "#experiment_warm_up_assignments")
      refute has_element?(view, "#experiment_max_condition_share")
      refute render(view) =~ "Coming soon"

      view
      |> element("#create-ab-experiment-form")
      |> render_change(%{"experiment" => %{"algorithm" => "thompson_sampling"}})

      refute has_element?(view, "#thompson-sampling-options")

      view
      |> element("#create-ab-experiment-form")
      |> render_submit(%{
        "experiment" => %{
          "name" => "Adaptive Study",
          "slug" => "adaptive-study",
          "algorithm" => "thompson_sampling",
          "alternatives_resource_id" => selected_decision_point_value(view)
        }
      })

      assert has_element?(view, "#ab-experiments-table", "Adaptive Study")
      assert has_element?(view, "#ab-experiments-table", "Thompson Sampling")
      assert has_element?(view, "#ab-experiments-table", "Draft")

      id = experiment_id(view)

      {:ok, details_view, _html} =
        live(conn, ~p"/workspaces/course_author/#{project.slug}/experiments/#{id}")

      assert has_element?(details_view, "#experiment-prior_alpha[value='1.0']")
      assert has_element?(details_view, "#experiment-prior_beta[value='1.0']")
      assert has_element?(details_view, "#experiment-warm_up_assignments[value='0']")
      assert has_element?(details_view, "#experiment-max_condition_share[value='1.0']")
      assert has_element?(details_view, "label[for='condition-0-weight']", "Warm-up weight")

      assert has_element?(
               details_view,
               "#condition-0-weight-help[data-tooltip*='do not need to sum to 1'][data-tooltip*='2:1']"
             )

      assert has_element?(details_view, "#condition-0-weight[min='0.0001'][step='any']")
      refute has_element?(details_view, "#experiment-configuration pre")

      details_view
      |> form("#experiment-configuration-form", %{
        "configuration" => %{"prior_alpha" => "not-a-number"}
      })
      |> render_change()

      assert has_element?(details_view, "#experiment-prior_alpha[value='1.0']")
      assert has_element?(details_view, "button[type='submit'][disabled]", "Save configuration")

      details_view
      |> form("#experiment-configuration-form", %{
        "configuration" => %{"prior_alpha" => "2.0"}
      })
      |> render_change()

      refute has_element?(details_view, "button[type='submit'][disabled]", "Save configuration")

      details_view
      |> form("#experiment-configuration-form", %{
        "configuration" => %{"prior_alpha" => "1.0"}
      })
      |> render_change()

      assert has_element?(details_view, "button[type='submit'][disabled]", "Save configuration")

      assert has_element?(
               details_view,
               "#experiment-policy-configuration",
               "Assignment policy and guardrails"
             )

      assert has_element?(
               details_view,
               "#experiment-policy-configuration",
               "These settings apply to every intervention in this experiment."
             )

      configure_intervention(details_view, project, group.resource_id, :thompson_sampling)

      details_view
      |> element("button[phx-click='start_experiment']", "Start")
      |> render_click()

      assert has_element?(details_view, "#experiment-configuration", "Active")

      assert has_element?(
               details_view,
               "#experiment-policy-report",
               "Estimated success probability"
             )

      assert has_element?(details_view, "#policy-snapshot-table", "50.0%")

      assert has_element?(
               details_view,
               "button.btn-link[phx-click='refresh_policy_snapshot'] .fa-rotate-right"
             )

      assert has_element?(details_view, "details[id^='policy-technical-details-']", "Posterior α")
      refute render(details_view) =~ "next-assignment probability"
      assert has_element?(details_view, "#condition-0-label[disabled]")
      assert has_element?(details_view, "#condition-0-option[disabled]")
      assert has_element?(details_view, "#condition-0-weight[disabled]")
      refute has_element?(details_view, "#condition-0-active[disabled]")

      condition = Repo.get_by!(Condition, experiment_id: id, position: 0)

      details_view
      |> element("#condition-0-active")
      |> render_change(%{
        "configuration" => %{"conditions" => %{"0" => %{"active" => "false"}}}
      })

      assert Repo.get!(Condition, condition.id).active
      refute has_element?(details_view, "button[type='submit'][disabled]", "Save configuration")

      details_view
      |> form("#experiment-configuration-form")
      |> render_submit(%{"configuration" => %{}})

      refute Repo.get!(Condition, condition.id).active
      assert has_element?(details_view, "button[type='submit'][disabled]", "Save configuration")

      refute has_element?(details_view, "button", "Remove decision point")
      refute has_element?(details_view, "button", "Remove intervention")
      refute has_element?(details_view, "button", "Add intervention")
      assert has_element?(details_view, "button[type='submit'][disabled]", "Save configuration")

      assert has_element?(
               details_view,
               "[phx-hook='GlobalTooltip'][data-tooltip-style='body'][aria-label^='About Posterior α:']"
             )

      assert has_element?(
               details_view,
               "[phx-hook='GlobalTooltip'][data-tooltip-style='body'][aria-label^='About Policy status:']"
             )
    end

    test "keeps experiment configuration singular", %{
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
          "name" => "Singular Study",
          "slug" => "singular-study",
          "algorithm" => "weighted_random",
          "alternatives_resource_id" =>
            project_experiments(view)
            |> hd()
            |> Map.fetch!(:alternatives_resource_id)
            |> to_string(),
          "weight_a" => "1",
          "weight_b" => "1"
        }
      })

      {:ok, details_view, _html} =
        live(
          conn,
          ~p"/workspaces/course_author/#{project.slug}/experiments/#{experiment_id(view)}"
        )

      assert has_element?(details_view, "#experiment-policy-configuration")
      assert has_element?(details_view, "#experiment-policy-configuration", "Conditions")
      refute has_element?(details_view, "#experiment-policy-configuration", "Shared conditions")
      refute has_element?(details_view, "#experiment-policy-configuration", "Condition mapping")
      assert has_element?(details_view, "#condition-row-0 #condition-0-label")
      assert has_element?(details_view, "#condition-row-0 #condition-0-code")
      assert has_element?(details_view, "#condition-row-0 #condition-0-option")
      assert has_element?(details_view, "#condition-row-0 #condition-0-active")
      assert has_element?(details_view, "#condition-row-0 #condition-0-weight")
      assert has_element?(details_view, "label[for='condition-0-weight']", "Weight")

      assert has_element?(
               details_view,
               "#condition-0-weight-help[data-tooltip*='1 / 1 is an even split']"
             )

      refute has_element?(details_view, "#experiment-policy-configuration h4", "Decision Point 1")
      refute has_element?(details_view, "#experiment-assignment-policy")
      assert has_element?(details_view, "#experiment-details-grid", "Weighted random")
      refute has_element?(details_view, "#experiment-prior_alpha")

      details_view
      |> form("#experiment-configuration-form", %{
        "configuration" => %{
          "conditions" => %{
            "0" => %{"label" => "Edited condition label"}
          }
        }
      })
      |> render_change()

      assert has_element?(details_view, "#condition-0-label[value='Edited condition label']")

      assert has_element?(
               details_view,
               "div.mt-4.flex.justify-end > button[type='submit']",
               "Save configuration"
             )

      assert has_element?(details_view, "#experiment-details-grid", "Decision Point")
      refute has_element?(details_view, "[phx-click='open_add_decision_point']")
      refute has_element?(details_view, "[phx-click='remove_draft_decision_point']")
    end

    test "creation modal stays limited to policy, identity, and decision point fields", %{
      conn: conn,
      project: project
    } do
      insert_alternatives_group(project)
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))

      open_create_experiment(view)

      view
      |> element("#create-ab-experiment-form")
      |> render_change(%{"experiment" => %{"algorithm" => "thompson_sampling"}})

      assert has_element?(view, "#experiment_algorithm")
      assert has_element?(view, "#experiment_name")
      assert has_element?(view, "#experiment_slug")
      assert has_element?(view, "#experiment_alternatives_resource")

      assert length(
               Floki.find(
                 Floki.parse_fragment!(render(view)),
                 "#create-ab-experiment-form input, #create-ab-experiment-form select"
               )
             ) == 4
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
               "Create a Decision Point before adding an A/B Testing experiment."
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
      assert has_element?(view, "#experiment_alternatives_resource option", "Decision Point")
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

  defp insert_alternatives_group(project, author \\ nil, title \\ "Decision Point") do
    resource = insert(:resource)
    insert(:project_resource, project_id: project.id, resource_id: resource.id)

    revision =
      insert(:revision, %{
        resource: resource,
        author: author,
        resource_type_id: ResourceType.id_for_alternatives(),
        title: title,
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

  defp configure_intervention(view, project, alternatives_resource_id, algorithm) do
    other_group = insert_alternatives_group(project, nil, "Other Decision Point")

    intervention =
      insert_project_page(project, "Intervention", false, %{
        "model" => [
          %{
            "type" => "alternatives",
            "id" => "placement-a",
            "alternatives_id" => alternatives_resource_id,
            "children" => [
              %{
                "type" => "alternative",
                "children" => [
                  %{"type" => "p", "children" => [%{"text" => "Welcome intervention"}]},
                  %{"type" => "activity-reference", "activity_id" => 123}
                ]
              }
            ]
          },
          %{
            "type" => "alternatives",
            "id" => "other-placement",
            "alternatives_id" => other_group.resource_id,
            "children" => []
          }
        ]
      })

    assessment = insert_project_page(project, "Assessment", true, %{"model" => []})
    alternate = insert_project_page(project, "Alternate intervention", false, %{"model" => []})

    for ordinal <- 1..8 do
      insert_project_page(project, "ZZ Picker page #{ordinal}", false, %{"model" => []})
    end

    view
    |> element("button[phx-click='add_draft_intervention']")
    |> render_click()

    refute has_element?(view, "button[type='submit'][disabled]", "Save configuration")

    view
    |> element("button[phx-click='remove_draft_intervention']")
    |> render_click()

    assert has_element?(view, "button[type='submit'][disabled]", "Save configuration")

    view
    |> element("button[phx-click='add_draft_intervention']")
    |> render_click()

    open_picker(view, "intervention_page")

    view
    |> element("button[phx-click='change_picker_page'][phx-value-offset='8']", "2")
    |> render_click()

    view
    |> element("button[phx-click='change_picker_page'][phx-value-offset='0']", "1")
    |> render_click()

    assert has_element?(
             view,
             "#experiment-option-picker-table tr[phx-value-id='#{intervention.resource_id}']"
           )

    assert has_element?(
             view,
             "#experiment-option-picker-table tr[phx-value-id='#{assessment.resource_id}']"
           )

    view
    |> element("#experiment-option-picker-table tr[phx-value-id='#{alternate.resource_id}']")
    |> render_click()

    assert has_element?(
             view,
             "#experiment-option-picker-table tr[phx-value-id='#{alternate.resource_id}'] input[checked]"
           )

    view
    |> element("#experiment-option-picker-table tr[phx-value-id='#{intervention.resource_id}']")
    |> render_click()

    refute has_element?(
             view,
             "#experiment-option-picker-table tr[phx-value-id='#{alternate.resource_id}'] input[checked]"
           )

    assert has_element?(
             view,
             "#experiment-option-picker-table tr[phx-value-id='#{intervention.resource_id}'] input[checked]"
           )

    submit_picker(view, intervention.resource_id)

    open_picker(view, "placement_element")

    assert has_element?(
             view,
             "#experiment-option-picker-table tr[phx-value-id='placement-a']"
           )

    refute has_element?(
             view,
             "#experiment-option-picker-table tr[phx-value-id='other-placement']"
           )

    assert has_element?(view, "#experiment-option-picker-table", "Alternative Content")
    assert has_element?(view, "#experiment-option-picker-table", "Welcome intervention")
    assert has_element?(view, "#experiment-option-picker-table", "[Activity]")
    refute has_element?(view, "#experiment-option-picker-table", "unsupported")

    assert has_element?(
             view,
             "#experiment-option-picker",
             "Elements are listed in the order they appear on the page"
           )

    assert has_element?(view, "#experiment-option-picker-table th", "Position")

    assert has_element?(
             view,
             "#experiment-option-picker-table tr[phx-value-id='placement-a']",
             "1"
           )

    submit_picker(view, "placement-a")

    if algorithm == :thompson_sampling do
      open_picker(view, "assessment_page")

      assert has_element?(
               view,
               "#experiment-option-picker-table tr[phx-value-id='#{assessment.resource_id}']"
             )

      refute has_element?(
               view,
               "#experiment-option-picker-table tr[phx-value-id='#{intervention.resource_id}']"
             )

      submit_picker(view, assessment.resource_id)
    end

    params = %{
      "algorithm" => Atom.to_string(algorithm),
      "interventions" => %{
        "0" => %{
          "reward_threshold" => "0.7"
        }
      }
    }

    view
    |> form("#experiment-configuration-form", %{"configuration" => params})
    |> render_submit()

    assert has_element?(view, "[role='status']", "Experiment configuration saved.")
  end

  defp open_picker(view, kind) do
    view
    |> element(
      "input[phx-click='open_option_picker'][phx-value-kind='#{kind}'][phx-value-intervention-index='0']"
    )
    |> render_click()
  end

  defp submit_picker(view, value) do
    view
    |> element("#experiment-option-picker-table tr[phx-value-id='#{value}']")
    |> render_click()

    assert has_element?(
             view,
             "#experiment-option-picker-table tr[phx-value-id='#{value}'] input[checked]"
           )

    view
    |> element("#experiment-option-picker button[phx-click='select_picker_option']", "Select")
    |> render_click()
  end

  defp insert_project_page(project, title, graded, content) do
    resource = insert(:resource)
    insert(:project_resource, project_id: project.id, resource_id: resource.id)

    revision =
      insert(:revision,
        resource: resource,
        resource_type_id: ResourceType.id_for_page(),
        title: title,
        graded: graded,
        content: content
      )

    publication = Oli.Publishing.project_working_publication(project.slug)
    insert(:published_resource, publication: publication, resource: resource, revision: revision)
    revision
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
