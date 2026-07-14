defmodule OliWeb.Delivery.Instructor.BankSelectionManagerLiveTest do
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.InstructorCustomizations
  alias Oli.Delivery.Sections
  alias Oli.Rendering.Content.JumpNavigation
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
        }) <> "#" <> JumpNavigation.selection_target_id("selection-1")

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
               "#bank-selection-customization-bridge[data-preview-customization-copy]"
             )

      assert has_element?(
               view,
               "#bank-selection-customization-bridge [data-preview-customization-status][role='status'][aria-live='polite'][phx-update='ignore']"
             )

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

    test "visibility filter toggles show all, available, and removed candidates",
         %{
           conn: conn,
           section: section,
           page_revision: page_revision,
           first_candidate: first_candidate,
           second_candidate: second_candidate,
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

      assert has_element?(view, "#candidate-visibility-all[aria-pressed=\"true\"]")
      assert has_element?(view, "#candidate-visibility-available[aria-pressed=\"false\"]")
      assert has_element?(view, "#candidate-visibility-removed[aria-pressed=\"false\"]")
      assert has_element?(view, "#candidate-row-#{first_candidate.resource_id}", "Removed")
      assert has_element?(view, "#candidate-row-#{second_candidate.resource_id}")
      assert has_element?(view, "div", "Showing 25 of 30 questions")

      view
      |> element("#candidate-visibility-available")
      |> render_click()

      assert has_element?(view, "#candidate-visibility-all[aria-pressed=\"false\"]")
      assert has_element?(view, "#candidate-visibility-available[aria-pressed=\"true\"]")
      assert has_element?(view, "#candidate-visibility-removed[aria-pressed=\"false\"]")
      refute has_element?(view, "#candidate-row-#{first_candidate.resource_id}")
      assert has_element?(view, "#candidate-row-#{second_candidate.resource_id}")
      assert has_element?(view, "div", "Showing 25 of 29 questions")

      view
      |> element("#candidate-visibility-removed")
      |> render_click()

      assert has_element?(view, "#candidate-visibility-all[aria-pressed=\"false\"]")
      assert has_element?(view, "#candidate-visibility-available[aria-pressed=\"false\"]")
      assert has_element?(view, "#candidate-visibility-removed[aria-pressed=\"true\"]")
      assert has_element?(view, "#candidate-row-#{first_candidate.resource_id}", "Removed")
      refute has_element?(view, "#candidate-row-#{second_candidate.resource_id}")
      assert has_element?(view, "div", "Showing 1 of 1 questions")
      refute has_element?(view, "#load-more-candidates")

      view
      |> element("#candidate-visibility-all")
      |> render_click()

      assert has_element?(view, "#candidate-visibility-all[aria-pressed=\"true\"]")
      assert has_element?(view, "#candidate-row-#{first_candidate.resource_id}", "Removed")
      assert has_element?(view, "#candidate-row-#{second_candidate.resource_id}")
      assert has_element?(view, "div", "Showing 25 of 30 questions")
    end

    test "removed visibility filter renders an empty state when no removed candidates match",
         %{
           conn: conn,
           section: section,
           page_revision: page_revision,
           first_candidate: first_candidate
         } do
      {:ok, view, _html} =
        live(conn, PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1"))

      view
      |> element("#candidate-visibility-removed")
      |> render_click()

      assert has_element?(view, "#candidate-visibility-removed[aria-pressed=\"true\"]")
      assert has_element?(view, "#candidate-list-empty-state")

      assert has_element?(
               view,
               "#candidate-list-empty-state",
               "No questions match the selected filters."
             )

      refute has_element?(view, "#candidate-row-#{first_candidate.resource_id}")
      assert has_element?(view, "div", "Showing 0 of 0 questions")
      refute has_element?(view, "#load-more-candidates")
      refute has_element?(view, "#selected-candidate-preview-#{first_candidate.resource_id}")
    end

    test "default empty candidate list renders neutral empty state", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      {:ok, view, _html} =
        live(
          conn,
          PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-empty")
        )

      assert has_element?(view, "#candidate-visibility-all[aria-pressed=\"true\"]")

      assert has_element?(
               view,
               "#candidate-list-empty-state",
               "No matching questions are currently available for this activity bank selection."
             )

      refute has_element?(
               view,
               "#candidate-list-empty-state",
               "No questions match the selected filters."
             )

      assert has_element?(view, "div", "Showing 0 of 0 questions")
    end

    test "search filters candidates dynamically and is preserved after remove",
         %{
           conn: conn,
           section: section,
           page_revision: page_revision,
           first_candidate: first_candidate,
           last_candidate: last_candidate
         } do
      {:ok, view, _html} =
        live(conn, PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1"))

      refute has_element?(view, "#candidate-row-#{last_candidate.resource_id}")

      view
      |> form("#candidate-search-form", %{"text_search" => "Candidate 30"})
      |> render_change()

      assert has_element?(view, "#candidate-search-input[value=\"Candidate 30\"]")
      assert has_element?(view, "#candidate-row-#{last_candidate.resource_id}")
      refute has_element?(view, "#candidate-row-#{first_candidate.resource_id}")
      assert has_element?(view, "div", "Showing 1 of 1 questions")
      refute has_element?(view, "#load-more-candidates")

      assert has_element?(
               view,
               "#selected-candidate-preview-#{last_candidate.resource_id}"
             )

      payload = %{
        "action" => "remove",
        "target" => %{
          "kind" => "bank_candidate",
          "pageResourceId" => page_revision.resource_id,
          "selectionId" => "selection-1",
          "activityResourceId" => last_candidate.resource_id
        }
      }

      view
      |> element("#bank-selection-customization-bridge")
      |> render_hook("toggle_preview_activity_customization", payload)

      assert has_element?(view, "#candidate-search-input[value=\"Candidate 30\"]")

      assert has_element?(
               view,
               "#candidate-row-#{last_candidate.resource_id}[data-candidate-enabled=\"false\"]",
               "Removed"
             )

      assert has_element?(view, "div", "Showing 1 of 1 questions")
    end

    test "search input is trimmed and capped before filtering", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      {:ok, view, _html} =
        live(conn, PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1"))

      capped_search = String.duplicate("x", 120)
      long_search = "   #{capped_search}#{String.duplicate("x", 20)}   "

      view
      |> form("#candidate-search-form", %{"text_search" => long_search})
      |> render_change()

      assert has_element?(view, "#candidate-search-input[value=\"#{capped_search}\"]")

      assert has_element?(
               view,
               "#candidate-list-empty-state",
               "No questions match the selected filters."
             )
    end

    test "advanced filter bar renders below visibility filters and combines multi-select filters",
         %{
           conn: conn,
           section: section,
           page_revision: page_revision,
           first_candidate: first_candidate,
           second_candidate: second_candidate,
           objective_2: objective_2
         } do
      {:ok, view, _html} =
        live(conn, PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1"))

      assert has_element?(view, "#candidate-advanced-filters #candidate-search-form")
      refute has_element?(view, "#candidate-visibility-filters #candidate-search-form")
      assert has_element?(view, "#candidate-objective-filter", "Learning Objectives")
      assert has_element?(view, "#candidate-objective-filter", "Learning Objective 1")
      assert has_element?(view, "#candidate-objective-filter", "Learning Objective 2")
      assert has_element?(view, "#candidate-activity-type-filter", "Question Type")

      view
      |> form("#candidate-objective-filter-form", %{
        "_candidate_filter_id" => "candidate-objective-filter",
        "objective_ids" => ["#{objective_2.resource_id}"]
      })
      |> render_change()

      assert has_element?(view, "#candidate-objective-filter[open]")
      assert has_element?(view, "#candidate-objective-filter", "Learning Objectives (1)")
      refute has_element?(view, "#candidate-row-#{first_candidate.resource_id}")
      assert has_element?(view, "#candidate-row-#{second_candidate.resource_id}")
      assert has_element?(view, "div", "Showing 15 of 15 questions")

      view
      |> element("#candidate-objective-filter-toggle")
      |> render_click()

      refute has_element?(view, "#candidate-objective-filter[open]")

      cata_registration = Oli.Activities.get_registration_by_slug("oli_check_all_that_apply")

      view
      |> form("#candidate-activity-type-filter-form", %{
        "_candidate_filter_id" => "candidate-activity-type-filter",
        "activity_type_ids" => ["#{cata_registration.id}"]
      })
      |> render_change()

      assert has_element?(view, "#candidate-objective-filter", "Learning Objectives (1)")
      assert has_element?(view, "#candidate-activity-type-filter[open]")
      assert has_element?(view, "#candidate-activity-type-filter", "Question Type (1)")
      refute has_element?(view, "#candidate-row-#{first_candidate.resource_id}")
      assert has_element?(view, "#candidate-row-#{second_candidate.resource_id}")
      assert has_element?(view, "div", "Showing 15 of 15 questions")

      view
      |> form("#candidate-search-form", %{"text_search" => "does-not-match-any-question"})
      |> render_change()

      assert has_element?(
               view,
               "#candidate-list-empty-state",
               "No questions match the selected filters."
             )

      assert has_element?(view, "div", "Showing 0 of 0 questions")
    end

    test "clear all resets every candidate filter and preserves visible checkbox selections",
         %{
           conn: conn,
           section: section,
           page_revision: page_revision,
           first_candidate: first_candidate,
           second_candidate: second_candidate,
           objective_2: objective_2
         } do
      {:ok, view, _html} =
        live(conn, PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1"))

      view
      |> element("#candidate-checkbox-#{second_candidate.resource_id}")
      |> render_click()

      assert has_element?(view, "#candidate-checkbox-#{second_candidate.resource_id}[checked]")

      view
      |> element("#candidate-visibility-available")
      |> render_click()

      view
      |> form("#candidate-search-form", %{"text_search" => "Candidate 2"})
      |> render_change()

      view
      |> form("#candidate-objective-filter-form", %{
        "_candidate_filter_id" => "candidate-objective-filter",
        "objective_ids" => ["#{objective_2.resource_id}"]
      })
      |> render_change()

      cata_registration = Oli.Activities.get_registration_by_slug("oli_check_all_that_apply")

      view
      |> form("#candidate-activity-type-filter-form", %{
        "_candidate_filter_id" => "candidate-activity-type-filter",
        "activity_type_ids" => ["#{cata_registration.id}"]
      })
      |> render_change()

      assert has_element?(view, "#candidate-visibility-available[aria-pressed=\"true\"]")
      assert has_element?(view, "#candidate-search-input[value=\"Candidate 2\"]")
      assert has_element?(view, "#candidate-objective-filter", "Learning Objectives (1)")
      assert has_element?(view, "#candidate-activity-type-filter", "Question Type (1)")
      assert has_element?(view, "#candidate-row-#{second_candidate.resource_id}")
      refute has_element?(view, "#candidate-row-#{first_candidate.resource_id}")
      assert has_element?(view, "div", "Showing 1 of 1 questions")

      view
      |> element("#candidate-clear-filters")
      |> render_click()

      assert has_element?(view, "#candidate-visibility-all[aria-pressed=\"true\"]")
      assert has_element?(view, "#candidate-search-input[value=\"\"]")
      assert has_element?(view, "#candidate-objective-filter", "Learning Objectives")
      assert has_element?(view, "#candidate-activity-type-filter", "Question Type")
      refute has_element?(view, "#candidate-objective-filter[open]")
      refute has_element?(view, "#candidate-activity-type-filter[open]")
      assert has_element?(view, "#candidate-row-#{first_candidate.resource_id}")
      assert has_element?(view, "#candidate-row-#{second_candidate.resource_id}")
      assert has_element?(view, "#candidate-checkbox-#{second_candidate.resource_id}[checked]")
      assert has_element?(view, "div", "Showing 25 of 30 questions")
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

    test "candidate filter event resets paging and selected preview to the filtered result set",
         %{
           conn: conn,
           section: section,
           page_revision: page_revision,
           first_candidate: first_candidate,
           second_candidate: second_candidate,
           last_candidate: last_candidate
         } do
      {:ok, view, _html} =
        live(conn, PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1"))

      view
      |> element("#load-more-candidates")
      |> render_click()

      assert has_element?(view, "#candidate-row-#{last_candidate.resource_id}")

      view
      |> element("#candidate-select-#{last_candidate.resource_id}")
      |> render_click()

      assert has_element?(
               view,
               "#selected-candidate-preview-#{last_candidate.resource_id}"
             )

      mcq_registration = Oli.Activities.get_registration_by_slug("oli_multiple_choice")

      view
      |> element("#bank-selection-customization-bridge")
      |> render_hook("filter_candidates", %{"activity_type_ids" => "#{mcq_registration.id}"})

      assert has_element?(view, "#candidate-row-#{first_candidate.resource_id}")
      refute has_element?(view, "#candidate-row-#{second_candidate.resource_id}")
      refute has_element?(view, "#candidate-row-#{last_candidate.resource_id}")

      assert has_element?(
               view,
               "#selected-candidate-preview-#{first_candidate.resource_id}"
             )

      assert has_element?(view, "div", "Showing 15 of 15 questions")
      refute has_element?(view, "#load-more-candidates")
    end

    test "candidate filter event ignores malformed filter values without crashing",
         %{
           conn: conn,
           section: section,
           page_revision: page_revision,
           first_candidate: first_candidate
         } do
      {:ok, view, _html} =
        live(conn, PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1"))

      assert has_element?(view, "#candidate-row-#{first_candidate.resource_id}")

      view
      |> element("#bank-selection-customization-bridge")
      |> render_hook("filter_candidates", %{
        "activity_type_ids" => %{"bad" => "shape"},
        "objective_ids" => [%{"also" => "bad"}]
      })

      assert has_element?(view, "#candidate-row-#{first_candidate.resource_id}")
      assert has_element?(view, "div", "Showing 25 of 30 questions")
      assert has_element?(view, "#selected-candidate-preview-#{first_candidate.resource_id}")
    end

    test "candidate checkboxes keep same-state selection and header checkbox respects the current selection mode",
         %{
           conn: conn,
           section: section,
           page_revision: page_revision,
           user: user,
           first_candidate: first_candidate,
           second_candidate: second_candidate,
           third_candidate: third_candidate
         } do
      assert {:ok, _view} =
               InstructorCustomizations.exclude_bank_candidate(
                 section,
                 page_revision.resource_id,
                 "selection-1",
                 second_candidate.resource_id,
                 actor: user
               )

      assert {:ok, _view} =
               InstructorCustomizations.exclude_bank_candidate(
                 section,
                 page_revision.resource_id,
                 "selection-1",
                 third_candidate.resource_id,
                 actor: user
               )

      {:ok, view, _html} =
        live(conn, PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1"))

      assert has_element?(view, "#selected-candidate-preview-#{first_candidate.resource_id}")
      refute has_element?(view, "#candidate-checkbox-#{second_candidate.resource_id}[checked]")
      refute has_element?(view, "#candidate-checkbox-#{third_candidate.resource_id}[checked]")

      view
      |> element("#candidate-checkbox-#{second_candidate.resource_id}")
      |> render_click()

      assert has_element?(view, "#candidate-checkbox-#{second_candidate.resource_id}[checked]")
      assert has_element?(view, "#selected-candidate-preview-#{first_candidate.resource_id}")

      assert has_element?(
               view,
               "#candidate-checkbox-#{second_candidate.resource_id}[data-selection-mode=\"removed\"]"
             )

      assert has_element?(view, "#candidate-checkbox-#{first_candidate.resource_id}[disabled]")

      refute has_element?(view, "#candidate-checkbox-#{first_candidate.resource_id}[checked]")
      assert has_element?(view, "#candidate-checkbox-#{second_candidate.resource_id}[checked]")

      view
      |> element("#candidate-list-header-checkbox")
      |> render_click()

      assert has_element?(view, "#candidate-list-header-checkbox[checked]")
      assert has_element?(view, "#candidate-checkbox-#{second_candidate.resource_id}[checked]")
      assert has_element?(view, "#candidate-checkbox-#{third_candidate.resource_id}[checked]")
      refute has_element?(view, "#candidate-checkbox-#{first_candidate.resource_id}[checked]")

      view
      |> element("#candidate-list-header-checkbox")
      |> render_click()

      refute has_element?(view, "#candidate-list-header-checkbox[checked]")
      refute has_element?(view, "#candidate-checkbox-#{second_candidate.resource_id}[checked]")
      refute has_element?(view, "#candidate-checkbox-#{third_candidate.resource_id}[checked]")
      assert has_element?(view, "#selected-candidate-preview-#{first_candidate.resource_id}")
    end

    test "master checkbox prefers available rows when no selection mode is active",
         %{
           conn: conn,
           section: section,
           page_revision: page_revision,
           user: user,
           first_candidate: first_candidate,
           second_candidate: second_candidate,
           third_candidate: third_candidate
         } do
      assert {:ok, _view} =
               InstructorCustomizations.exclude_bank_candidate(
                 section,
                 page_revision.resource_id,
                 "selection-1",
                 second_candidate.resource_id,
                 actor: user
               )

      assert {:ok, _view} =
               InstructorCustomizations.exclude_bank_candidate(
                 section,
                 page_revision.resource_id,
                 "selection-1",
                 third_candidate.resource_id,
                 actor: user
               )

      {:ok, view, _html} =
        live(conn, PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1"))

      view
      |> element("#candidate-list-header-checkbox")
      |> render_click()

      assert has_element?(view, "#candidate-list-header-checkbox[checked]")
      assert has_element?(view, "#candidate-checkbox-#{first_candidate.resource_id}[checked]")
      refute has_element?(view, "#candidate-checkbox-#{second_candidate.resource_id}[checked]")
      refute has_element?(view, "#candidate-checkbox-#{third_candidate.resource_id}[checked]")

      view
      |> element("#candidate-list-header-checkbox")
      |> render_click()

      refute has_element?(view, "#candidate-list-header-checkbox[checked]")
      refute has_element?(view, "#candidate-checkbox-#{first_candidate.resource_id}[checked]")
    end

    test "master checkbox selects all visible available rows by default without mixing removed rows",
         %{
           conn: conn,
           section: section,
           page_revision: page_revision,
           user: user,
           first_candidate: first_candidate,
           second_candidate: second_candidate,
           third_candidate: third_candidate
         } do
      assert {:ok, _view} =
               InstructorCustomizations.exclude_bank_candidate(
                 section,
                 page_revision.resource_id,
                 "selection-1",
                 second_candidate.resource_id,
                 actor: user
               )

      {:ok, view, _html} =
        live(conn, PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1"))

      view
      |> element("#candidate-list-header-checkbox")
      |> render_click()

      assert has_element?(view, "#candidate-list-header-checkbox[checked]")
      assert has_element?(view, "#candidate-checkbox-#{first_candidate.resource_id}[checked]")
      assert has_element?(view, "#candidate-checkbox-#{third_candidate.resource_id}[checked]")
      refute has_element?(view, "#candidate-checkbox-#{second_candidate.resource_id}[checked]")

      view
      |> element("#candidate-list-header-checkbox")
      |> render_click()

      refute has_element?(view, "#candidate-list-header-checkbox[checked]")
      refute has_element?(view, "#candidate-checkbox-#{first_candidate.resource_id}[checked]")
      refute has_element?(view, "#candidate-checkbox-#{third_candidate.resource_id}[checked]")
      refute has_element?(view, "#candidate-checkbox-#{second_candidate.resource_id}[checked]")
    end

    test "available bulk selection shows remove CTA, disables preview remove action, and bulk remove refreshes state",
         %{
           conn: conn,
           section: section,
           page_revision: page_revision,
           first_candidate: first_candidate
         } do
      {:ok, view, _html} =
        live(conn, PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1"))

      view
      |> element("#candidate-checkbox-#{first_candidate.resource_id}")
      |> render_click()

      assert has_element?(view, "#bulk-selection-action-button", "Remove Selected (1)")

      assert has_element?(
               view,
               "[id^=\"selected-candidate-preview-shell-#{first_candidate.resource_id}-\"][data-bulk-selection-active=\"true\"]"
             )

      view
      |> element("#bulk-selection-action-button")
      |> render_click()

      assert has_element?(
               view,
               "#candidate-row-#{first_candidate.resource_id}[data-candidate-enabled=\"false\"]",
               "Removed"
             )

      assert has_element?(view, "#active-available-count", "29")
      assert has_element?(view, "#bulk-selection-action-button", "Restore Selected (1)")

      assert has_element?(
               view,
               "#flash_container",
               "1 question removed from this activity bank selection."
             )
    end

    test "removed bulk selection shows restore CTA, mutes opposite-state visible rows, and bulk restore refreshes state",
         %{
           conn: conn,
           section: section,
           page_revision: page_revision,
           user: user,
           first_candidate: first_candidate,
           second_candidate: second_candidate
         } do
      assert {:ok, _view} =
               InstructorCustomizations.exclude_bank_candidate(
                 section,
                 page_revision.resource_id,
                 "selection-1",
                 second_candidate.resource_id,
                 actor: user
               )

      {:ok, view, _html} =
        live(conn, PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1"))

      view
      |> element("#candidate-checkbox-#{second_candidate.resource_id}")
      |> render_click()

      assert has_element?(view, "#bulk-selection-action-button", "Restore Selected (1)")

      assert has_element?(
               view,
               "#candidate-row-#{first_candidate.resource_id}[data-candidate-selectable=\"false\"].opacity-50"
             )

      assert has_element?(view, "#candidate-checkbox-#{first_candidate.resource_id}[disabled]")

      view
      |> element("#bulk-selection-action-button")
      |> render_click()

      assert has_element?(
               view,
               "#candidate-row-#{second_candidate.resource_id}[data-candidate-enabled=\"true\"]"
             )

      assert has_element?(view, "#active-available-count", "30")
      assert has_element?(view, "#bulk-selection-action-button", "Remove Selected (1)")

      assert has_element?(
               view,
               "#flash_container",
               "1 question restored to this activity bank selection."
             )
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
        }) <> "#" <> JumpNavigation.selection_target_id("selection-1")

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

    test "invalid bulk removal opens the plural warning modal and persists nothing", %{
      conn: conn,
      section: section,
      page_revision: page_revision,
      user: user,
      candidates: candidates,
      first_candidate: first_candidate,
      second_candidate: second_candidate,
      third_candidate: third_candidate
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

      {:ok, view, _html} =
        live(conn, PreviewRoutes.selection_path(section.slug, page_revision.slug, "selection-1"))

      view
      |> element("#candidate-checkbox-#{second_candidate.resource_id}")
      |> render_click()

      view
      |> element("#candidate-checkbox-#{third_candidate.resource_id}")
      |> render_click()

      assert has_element?(view, "#bulk-selection-action-button", "Remove Selected (2)")

      view
      |> element("#bulk-selection-action-button")
      |> render_click()

      assert has_element?(view, "#invalid-remove-bank-modal", "Cannot remove these questions")

      assert has_element?(
               view,
               "#invalid-remove-bank-modal",
               "removing these 2 questions"
             )

      assert has_element?(view, "#invalid-remove-bank-modal", "Keep questions")

      assert has_element?(
               view,
               "#candidate-row-#{second_candidate.resource_id}[data-candidate-enabled=\"true\"]"
             )

      assert has_element?(
               view,
               "#candidate-row-#{third_candidate.resource_id}[data-candidate-enabled=\"true\"]"
             )

      refute Enum.any?(
               InstructorCustomizations.get_page_exclusions(section, page_revision.resource_id),
               fn exclusion ->
                 exclusion.kind == :bank_candidate and
                   exclusion.selection_id == "selection-1" and
                   exclusion.excluded_resource_id in [
                     second_candidate.resource_id,
                     third_candidate.resource_id
                   ]
               end
             )

      # Preserve the still-visible checked ids after the failed bulk validation.
      assert has_element?(view, "#bulk-selection-action-button", "Remove Selected (2)")
      refute has_element?(view, "#candidate-checkbox-#{first_candidate.resource_id}[checked]")
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

    objective_1 =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Learning Objective 1",
        scope: "embedded",
        content: %{},
        objectives: %{}
      )

    objective_2 =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Learning Objective 2",
        scope: "embedded",
        content: %{},
        objectives: %{}
      )

    candidates =
      Enum.map(1..30, fn index ->
        activity_type = Enum.at(activity_types, rem(index - 1, length(activity_types)))
        objective = if rem(index, 2) == 0, do: objective_2, else: objective_1

        insert(:revision,
          resource_type_id: ResourceType.id_for_activity(),
          activity_type_id: activity_type.id,
          title: "Candidate #{index}",
          scope: "banked",
          content: %{"model" => %{"stem" => "Candidate #{index}"}},
          objectives: %{"1" => [objective.resource_id]}
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
            },
            %{
              "type" => "selection",
              "id" => "selection-empty",
              "logic" => %{
                "conditions" => %{
                  "fact" => "objectives",
                  "operator" => "contains",
                  "value" => [objective_2.resource_id + 1_000_000]
                }
              },
              "count" => 1,
              "pointsPerActivity" => 1
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

    revisions = [root_revision, page_revision, objective_1, objective_2 | candidates]

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
     objective_1: objective_1,
     objective_2: objective_2,
     candidates: candidates,
     first_candidate: hd(candidates),
     second_candidate: Enum.at(candidates, 1),
     third_candidate: Enum.at(candidates, 2),
     last_candidate: List.last(candidates)}
  end

  defp cache_lti_context(section, user) do
    Oli.Lti.TestHelpers.all_default_claims()
    |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.context_id)
    |> cache_lti_params(user.id)
  end
end
