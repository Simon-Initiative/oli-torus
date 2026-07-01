defmodule OliWeb.Delivery.Instructor.BankSelectionManagerLiveTest do
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.InstructorCustomizations
  alias Oli.Delivery.Sections
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias Oli.Resources.ResourceType
  alias OliWeb.Delivery.Instructor.PreviewPageContext
  alias OliWeb.Delivery.Instructor.PreviewRoutes

  describe "bank selection manager preview route" do
    setup [:setup_preview_section_with_selection]

    test "selection_path helper points to the preview-session live route", %{
      section: section,
      page_revision: page_revision
    } do
      assert PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1") ==
               "/sections/#{section.slug}/preview/lesson/#{page_revision.slug}/selection/selection-1"
    end

    test "authorized preview users can open the manager shell with counts, rows, and local back behavior",
         %{
           conn: conn,
           section: section,
           page_revision: page_revision,
           first_candidate: first_candidate
         } do
      request_path =
        PreviewRoutes.lesson_path(section.slug, page_revision.slug, %{
          "sidebar_expanded" => "false"
        })

      {:ok, view, html} =
        live(
          conn,
          PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1", %{
            "request_path" => request_path,
            "return_to" => "/sections/#{section.slug}/remix?from=curriculum"
          })
        )

      assert html =~ ~s|id="instructor-preview-header"|
      assert html =~ ~s|id="bank-selection-manager"|
      assert html =~ "Activity Bank Selection"
      assert html =~ "Selection criteria"
      assert html =~ "Points per question:"
      assert html =~ ">4<"
      assert has_element?(view, "#questions-required-count", "2")
      assert has_element?(view, "#active-available-count", "30")
      assert html =~ "No criteria configured."
      assert html =~ "/js/oli_multiple_choice_preview.js"
      assert html =~ "/js/oli_check_all_that_apply_preview.js"

      assert has_element?(
               view,
               "#selected-candidate-preview-#{first_candidate.resource_id}"
             )

      assert has_element?(
               view,
               ~s{a[href="#{request_path}"]},
               "Back"
             )

      assert has_element?(view, "#candidate-row-#{first_candidate.resource_id}")
      assert has_element?(view, "#load-more-candidates", "Load 5 more (5 remaining)")
    end

    test "bank candidate preview helper returns preview html", %{
      section: section,
      page_revision: page_revision,
      first_candidate: first_candidate
    } do
      assert {:ok, %{html: html}} =
               PreviewPageContext.build_bank_candidate_preview(
                 section,
                 page_revision,
                 first_candidate,
                 selection_id: "selection-1",
                 can_customize?: true,
                 actions: [%{kind: "remove", label: "Remove"}]
               )

      assert html =~ first_candidate.title
      assert html =~ "Remove"
    end

    test "removed candidate rows render removed styling and status text", %{
      conn: conn,
      section: section,
      page_revision: page_revision,
      first_candidate: first_candidate,
      user: user
    } do
      assert {:ok, _view} =
               InstructorCustomizations.exclude_bank_candidate(
                 section,
                 page_revision.resource_id,
                 "selection-1",
                 first_candidate.resource_id,
                 actor: user
               )

      {:ok, view, _html} =
        live(conn, PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1"))

      assert has_element?(
               view,
               "#candidate-row-#{first_candidate.resource_id}[data-candidate-enabled=\"false\"]",
               "Removed"
             )
    end

    test "selected row stays selected after loading an additional candidate page", %{
      conn: conn,
      section: section,
      page_revision: page_revision,
      second_candidate: second_candidate,
      last_candidate: last_candidate
    } do
      {:ok, view, _html} =
        live(conn, PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1"))

      refute has_element?(view, "#candidate-row-#{last_candidate.resource_id}")

      view
      |> element("#candidate-select-#{second_candidate.resource_id}")
      |> render_click()

      assert has_element?(
               view,
               "#selected-candidate-preview-#{second_candidate.resource_id}"
             )

      view
      |> element("#load-more-candidates")
      |> render_click()

      assert has_element?(view, "#candidate-row-#{last_candidate.resource_id}")

      assert has_element?(
               view,
               "#selected-candidate-preview-#{second_candidate.resource_id}"
             )
    end

    test "candidate checkboxes toggle independently from preview selection and header checkbox toggles all visible rows",
         %{
           conn: conn,
           section: section,
           page_revision: page_revision,
           first_candidate: first_candidate,
           second_candidate: second_candidate
         } do
      {:ok, view, _html} =
        live(conn, PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1"))

      assert has_element?(view, "#selected-candidate-preview-#{first_candidate.resource_id}")
      refute has_element?(view, "#candidate-checkbox-#{second_candidate.resource_id}[checked]")

      view
      |> element("#candidate-checkbox-#{second_candidate.resource_id}")
      |> render_click()

      assert has_element?(view, "#candidate-checkbox-#{second_candidate.resource_id}[checked]")
      assert has_element?(view, "#selected-candidate-preview-#{first_candidate.resource_id}")

      view
      |> element("#candidate-list-header-checkbox")
      |> render_click()

      assert has_element?(view, "#candidate-list-header-checkbox[checked]")
      assert has_element?(view, "#candidate-checkbox-#{first_candidate.resource_id}[checked]")
      assert has_element?(view, "#candidate-checkbox-#{second_candidate.resource_id}[checked]")

      view
      |> element("#candidate-list-header-checkbox")
      |> render_click()

      refute has_element?(view, "#candidate-list-header-checkbox[checked]")
      refute has_element?(view, "#candidate-checkbox-#{first_candidate.resource_id}[checked]")
      refute has_element?(view, "#candidate-checkbox-#{second_candidate.resource_id}[checked]")
      assert has_element?(view, "#selected-candidate-preview-#{first_candidate.resource_id}")
    end

    test "bank candidate customization events update exclusion state and row counts", %{
      conn: conn,
      section: section,
      page_revision: page_revision,
      first_candidate: first_candidate
    } do
      {:ok, view, _html} =
        live(conn, PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1"))

      payload = %{
        "action" => "remove",
        "target" => %{
          "kind" => "bank_candidate",
          "pageResourceId" => page_revision.resource_id,
          "selectionId" => "selection-1",
          "activityResourceId" => first_candidate.resource_id
        }
      }

      _reply =
        view
        |> element("#bank-selection-customization-bridge")
        |> render_hook("toggle_preview_activity_customization", payload)

      assert has_element?(
               view,
               "#candidate-row-#{first_candidate.resource_id}[data-candidate-enabled=\"false\"]",
               "Removed"
             )

      assert has_element?(view, "#active-available-count", "29")

      assert has_element?(
               view,
               "#flash_container",
               "Question removed from this activity bank selection."
             )

      exclusions =
        InstructorCustomizations.get_page_exclusions(section, page_revision.resource_id)

      assert Enum.any?(exclusions, fn exclusion ->
               exclusion.kind == :bank_candidate and
                 exclusion.selection_id == "selection-1" and
                 exclusion.excluded_resource_id == first_candidate.resource_id
             end)

      restore_payload = put_in(payload, ["action"], "restore")

      view
      |> element("#bank-selection-customization-bridge")
      |> render_hook("toggle_preview_activity_customization", restore_payload)

      assert has_element?(
               view,
               "#candidate-row-#{first_candidate.resource_id}[data-candidate-enabled=\"true\"]"
             )

      refute Enum.any?(
               InstructorCustomizations.get_page_exclusions(section, page_revision.resource_id),
               fn exclusion ->
                 exclusion.kind == :bank_candidate and
                   exclusion.selection_id == "selection-1" and
                   exclusion.excluded_resource_id == first_candidate.resource_id
               end
             )
    end

    test "invalid candidate removal opens a warning modal and remove bank redirects with flash",
         %{
           conn: conn,
           section: section,
           page_revision: page_revision,
           user: user,
           candidates: candidates,
           first_candidate: first_candidate,
           second_candidate: second_candidate
         } do
      Enum.each(Enum.drop(candidates, 3), fn candidate ->
        assert {:ok, _view} =
                 InstructorCustomizations.exclude_bank_candidate(
                   section,
                   page_revision.resource_id,
                   "selection-1",
                   candidate.resource_id,
                   actor: user
                 )
      end)

      request_path =
        PreviewRoutes.lesson_path(section.slug, page_revision.slug, %{
          "sidebar_expanded" => "false"
        })

      {:ok, view, _html} =
        live(
          conn,
          PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1", %{
            "request_path" => request_path
          })
        )

      first_remove = %{
        "action" => "remove",
        "target" => %{
          "kind" => "bank_candidate",
          "pageResourceId" => page_revision.resource_id,
          "selectionId" => "selection-1",
          "activityResourceId" => first_candidate.resource_id
        }
      }

      second_remove =
        put_in(
          first_remove,
          ["target", "activityResourceId"],
          second_candidate.resource_id
        )

      view
      |> element("#bank-selection-customization-bridge")
      |> render_hook("toggle_preview_activity_customization", first_remove)

      view
      |> element("#bank-selection-customization-bridge")
      |> render_hook("toggle_preview_activity_customization", second_remove)

      assert has_element?(
               view,
               "#invalid-remove-bank-modal",
               "Cannot remove this question"
             )

      assert has_element?(
               view,
               "#invalid-remove-bank-modal",
               "This activity bank selection requires 2 questions"
             )

      assert has_element?(view, "#invalid-remove-bank-modal", "would leave only 1")

      assert has_element?(
               view,
               "#candidate-row-#{second_candidate.resource_id}[data-candidate-enabled=\"true\"]"
             )

      dismiss_html =
        view
        |> element("#invalid-remove-bank-modal-keep-question")
        |> render_click()

      refute dismiss_html =~ "Cannot remove this question"

      view
      |> element("#bank-selection-customization-bridge")
      |> render_hook("toggle_preview_activity_customization", second_remove)

      assert has_element?(view, "#invalid-remove-bank-modal-remove-bank", "Remove bank")
      assert has_element?(view, "#invalid-remove-bank-modal-keep-question", "Keep question")

      view
      |> element("#invalid-remove-bank-modal-remove-bank")
      |> render_click()

      {path, flash} = assert_redirect(view)

      assert path == request_path
      assert flash["info"] == "Activity bank selection removed from this page."

      exclusions =
        InstructorCustomizations.get_page_exclusions(section, page_revision.resource_id)

      assert Enum.any?(exclusions, fn exclusion ->
               exclusion.kind == :bank_selection and exclusion.selection_id == "selection-1"
             end)
    end

    test "invalid selection redirects safely back to lesson preview and preserves only safe navigation params",
         %{
           conn: conn,
           section: section,
           page_revision: page_revision
         } do
      {:error, {:redirect, %{to: path, flash: flash}}} =
        live(
          conn,
          PreviewRoutes.selection_path(section.slug, page_revision.slug, "missing-selection", %{
            "return_to" => "/sections/#{section.slug}/remix?from=curriculum",
            "request_path" => "https://example.com/bad"
          })
        )

      assert path ==
               PreviewRoutes.lesson_path(section.slug, page_revision.slug, %{
                 "return_to" => "/sections/#{section.slug}/remix?from=curriculum"
               })

      assert flash["error"] == "We couldn’t find that activity bank selection for this page."
    end

    test "learner access is redirected out of preview mode by the existing section-preview plug",
         %{
           section: section,
           page_revision: page_revision
         } do
      learner = user_fixture(%{independent_learner: false})

      enroll_user_to_section(learner, section, :context_learner)
      cache_lti_context(section, learner)

      conn = build_conn() |> log_in_user(learner)

      {:error, {:redirect, %{to: path}}} =
        live(conn, PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1"))

      assert path ==
               "/sections/#{section.slug}/lesson/#{page_revision.slug}/selection/selection-1"
    end
  end

  defp setup_preview_section_with_selection(%{conn: conn}) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    activity_types = [
      Oli.Activities.get_registration_by_slug("oli_multiple_choice"),
      Oli.Activities.get_registration_by_slug("oli_check_all_that_apply")
    ]

    candidates =
      Enum.map(1..30, fn index ->
        activity_type = Enum.at(activity_types, rem(index - 1, length(activity_types)))

        insert(:revision,
          resource_type_id: ResourceType.id_for_activity(),
          activity_type_id: activity_type.id,
          title: "Candidate #{index}",
          scope: "banked",
          content: %{"model" => %{"stem" => "Candidate #{index}"}}
        )
      end)

    page_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        title: "bank selection page",
        slug: "bank_selection_page_preview",
        content: %{
          "model" => [
            %{
              "type" => "selection",
              "id" => "selection-1",
              "logic" => %{"conditions" => nil},
              "count" => 2,
              "pointsPerActivity" => 4
            }
          ]
        }
      )

    root_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        title: "Root",
        children: [page_revision.resource_id],
        content: %{}
      )

    revisions = [root_revision, page_revision | candidates]

    Enum.each(revisions, fn revision ->
      insert(:project_resource, project_id: project.id, resource_id: revision.resource_id)
    end)

    publication =
      insert(:publication, project: project, root_resource_id: root_revision.resource_id)

    Enum.each(revisions, fn revision ->
      insert(:published_resource,
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      )
    end)

    section = insert(:section, base_project: project)
    {:ok, section} = Sections.create_section_resources(section, publication)

    page_section_resource = Sections.get_section_resource(section.id, page_revision.resource_id)

    {:ok, _updated_section_resource} =
      Sections.update_section_resource(page_section_resource, %{
        graded: true,
        collab_space_config: %CollabSpaceConfig{status: :enabled}
      })

    user = user_fixture(%{independent_learner: false})

    Sections.enroll(user.id, section.id, [
      ContextRoles.get_role(:context_instructor)
    ])

    cache_lti_context(section, user)

    {:ok,
     conn: log_in_user(conn, user),
     user: user,
     section: section,
     page_revision: page_revision,
     candidates: candidates,
     first_candidate: hd(candidates),
     second_candidate: Enum.at(candidates, 1),
     last_candidate: List.last(candidates)}
  end

  defp cache_lti_context(section, user) do
    Oli.Lti.TestHelpers.all_default_claims()
    |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.context_id)
    |> cache_lti_params(user.id)
  end
end
