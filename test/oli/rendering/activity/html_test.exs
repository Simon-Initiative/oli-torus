defmodule Oli.Content.Activity.HtmlTest do
  use Oli.DataCase

  alias Oli.Rendering.Context
  alias Oli.Rendering.Activity
  alias Oli.Rendering.Activity.ActivitySummary
  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Delivery.Settings.Combined
  alias Oli.Accounts

  import ExUnit.CaptureLog

  describe "html activity renderer" do
    setup do
      author = author_fixture()

      %{author: author}
    end

    test "renders well-formed activity properly", %{author: author} do
      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{ \"active\": true }",
          model:
            "{ \"choices\": [ \"A\", \"B\", \"C\", \"D\" ], \"feedback\": [ \"A\", \"B\", \"C\", \"D\" ], \"stem\": \"\"}",
          delivery_element: "oli-multiple-choice-delivery",
          authoring_element: "oli-multiple-choice-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      element = %{
        "activity_id" => 1,
        "children" => [],
        "id" => 4_097_071_352,
        "purpose" => "none",
        "type" => "activity-reference"
      }

      rendered_html =
        Activity.render(
          %Context{user: author, activity_map: activity_map},
          element,
          Activity.Html
        )

      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

      assert rendered_html_string =~
               ~s|<oli-multiple-choice-delivery id="activity-1" phx-update="ignore" class="activity-container" state="{ "active": true }" model="{ "choices": [ "A", "B", "C", "D" ], "feedback": [ "A", "B", "C", "D" ], "stem": ""}"|
    end

    test "renders malformed activity gracefully", %{author: author} do
      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{ \"active\": true }",
          model:
            "{ \"choices\": [ \"A\", \"B\", \"C\", \"D\" ], \"feedback\": [ \"A\", \"B\", \"C\", \"D\" ], \"stem\": \"\"}",
          delivery_element: "oli-multiple-choice-delivery",
          authoring_element: "oli-multiple-choice-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      element = %{
        "children" => [],
        "id" => 4_097_071_352,
        "purpose" => "none",
        "type" => "activity-reference"
      }

      assert capture_log(fn ->
               rendered_html =
                 Activity.render(
                   %Context{user: author, activity_map: activity_map},
                   element,
                   Activity.Html
                 )

               rendered_html_string =
                 Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

               assert rendered_html_string =~
                        "<div class=\"alert alert-danger\">Activity render error"
             end) =~ "Activity render error"
    end

    test "handles missing activity from activity-map gracefully", %{author: author} do
      activity_map = %{
        5 => %ActivitySummary{
          id: 5,
          graded: false,
          state: "{ \"active\": true }",
          model:
            "{ \"choices\": [ \"A\", \"B\", \"C\", \"D\" ], \"feedback\": [ \"A\", \"B\", \"C\", \"D\" ], \"stem\": \"\"}",
          delivery_element: "oli-multiple-choice-delivery",
          authoring_element: "oli-multiple-choice-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      element = %{
        "activity_id" => 1,
        "children" => [],
        "id" => 4_097_071_352,
        "purpose" => "none",
        "type" => "activity-reference"
      }

      rendered_html =
        Activity.render(
          %Context{user: author, activity_map: activity_map},
          element,
          Activity.Html
        )

      rendered_html_string =
        Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

      assert rendered_html_string =~
               "<div class=\"alert alert-danger\">ActivitySummary with id 1 missing from activity_map"
    end

    test "renders preview elements for instructor preview when preview metadata is present", %{
      author: author
    } do
      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{ \"active\": true }",
          model: "{ \"stem\": \"Preview me\" }",
          delivery_element: "oli-multiple-choice-delivery",
          authoring_element: "oli-multiple-choice-authoring",
          preview_element: "oli-multiple-choice-preview",
          preview_script: "oli_multiple_choice_preview.js",
          preview_context: %{title: "Preview title", canCustomize: true},
          activity_type_slug: "oli_multiple_choice",
          script: "oli_multiple_choice_preview.js",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      element = %{"activity_id" => 1, "purpose" => "none"}

      rendered_html =
        Activity.render(
          %Context{user: author, activity_map: activity_map, mode: :instructor_preview},
          element,
          Activity.Html
        )

      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

      assert rendered_html_string =~ "instructor-preview-activity-wrapper"
      assert rendered_html_string =~ "<oli-multiple-choice-preview"
      assert rendered_html_string =~ "mode=\"preview\""
      assert rendered_html_string =~ "previewcontext="
      refute rendered_html_string =~ "authoringcontext="
    end

    test "logs and falls back to authoring elements for supported preview types without preview metadata",
         %{author: author} do
      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{ \"active\": true }",
          model: "{ \"stem\": \"Fallback me\" }",
          delivery_element: "oli-multiple-choice-delivery",
          authoring_element: "oli-multiple-choice-authoring",
          preview_context: %{
            activityTypeLabel: "Multiple Choice",
            title: "Fallback title",
            points: 1
          },
          activity_type_slug: "oli_multiple_choice",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      element = %{"activity_id" => 1, "purpose" => "none"}

      assert capture_log(fn ->
               rendered_html =
                 Activity.render(
                   %Context{user: author, activity_map: activity_map, mode: :instructor_preview},
                   element,
                   Activity.Html
                 )

               rendered_html_string =
                 Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

               assert rendered_html_string =~ "instructor-preview-activity-wrapper"
               assert rendered_html_string =~ "p-6"
               assert rendered_html_string =~ "border-Border-border-default"
               assert rendered_html_string =~ "bg-Surface-surface-primary"
               assert rendered_html_string =~ "Multiple Choice"
               assert rendered_html_string =~ "1 point"
               refute rendered_html_string =~ "1.0 point"
               assert rendered_html_string =~ "Fallback title"
               assert rendered_html_string =~ "<oli-multiple-choice-authoring"
               assert rendered_html_string =~ "mode=\"instructor_preview\""
             end) =~
               "Instructor preview falling back to authoring element for supported activity type oli_multiple_choice"
    end

    test "includes pageState from extrinsic_state when present", %{author: author} do
      # Create extrinsic state
      extrinsic_state = %{
        "app.explorations.bpr" => "test-value",
        "session.currentQuestionScore" => 5
      }

      resource_attempt = %ResourceAttempt{
        attempt_guid: "test-guid-123",
        state: %{}
      }

      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: true,
          state: "{ \"active\": true }",
          model: "{ \"stem\": \"test\" }",
          delivery_element: "oli-multiple-choice-delivery",
          authoring_element: "oli-multiple-choice-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "activity-guid-456",
          lifecycle_state: :active
        }
      }

      element = %{
        "activity_id" => 1,
        "purpose" => "none"
      }

      rendered_html =
        Activity.render(
          %Context{
            user: author,
            activity_map: activity_map,
            resource_attempt: resource_attempt,
            extrinsic_state: extrinsic_state,
            mode: :review
          },
          element,
          Activity.Html
        )

      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

      # Verify that the pageState contains the extrinsic state
      assert rendered_html_string =~ "app.explorations.bpr"
      assert rendered_html_string =~ "test-value"
      assert rendered_html_string =~ "session.currentQuestionScore"
    end

    test "includes user math preview preference in delivery context" do
      user = user_fixture()
      {:ok, user} = Accounts.set_user_preference(user, :show_math_previews?, false)

      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{ \"active\": true }",
          model: "{ \"stem\": \"test\" }",
          delivery_element: "oli-multiple-choice-delivery",
          authoring_element: "oli-multiple-choice-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "activity-guid-456",
          lifecycle_state: :active
        }
      }

      rendered_html =
        Activity.render(
          %Context{user: user, activity_map: activity_map},
          %{"activity_id" => 1, "purpose" => "none"},
          Activity.Html
        )

      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

      assert rendered_html_string =~ "&quot;showMathPreviews&quot;:false"
    end

    test "includes score-as-you-go reset messaging state in delivery context", %{author: author} do
      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: true,
          state: "{ \"active\": true }",
          model: "{ \"stem\": \"test\" }",
          delivery_element: "oli-multiple-choice-delivery",
          authoring_element: "oli-multiple-choice-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "activity-guid-456",
          lifecycle_state: :evaluated,
          aggregate_score: 0.75,
          aggregate_out_of: 1.0,
          aggregate_includes_current_attempt: true
        }
      }

      rendered_html =
        Activity.render(
          %Context{
            user: author,
            activity_map: activity_map,
            effective_settings: %Combined{
              replacement_strategy: :dynamic,
              scoring_strategy_id: 1,
              max_attempts: 4
            }
          },
          %{"activity_id" => 1, "purpose" => "none"},
          Activity.Html
        )

      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

      assert rendered_html_string =~ "&quot;aggregateScore&quot;:0.75"
      assert rendered_html_string =~ "&quot;aggregateOutOf&quot;:1.0"
      assert rendered_html_string =~ "&quot;aggregateIncludesCurrentAttempt&quot;:true"
      assert rendered_html_string =~ "&quot;replacementStrategy&quot;:&quot;dynamic&quot;"
    end

    test "uses empty map for pageState when extrinsic_state is nil", %{author: author} do
      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: true,
          state: "{ \"active\": true }",
          model: "{ \"stem\": \"test\" }",
          delivery_element: "oli-multiple-choice-delivery",
          authoring_element: "oli-multiple-choice-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "activity-guid-456",
          lifecycle_state: :active
        }
      }

      element = %{
        "activity_id" => 1,
        "purpose" => "none"
      }

      rendered_html =
        Activity.render(
          %Context{
            user: author,
            activity_map: activity_map,
            resource_attempt: nil,
            extrinsic_state: nil,
            mode: :review
          },
          element,
          Activity.Html
        )

      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

      # Should render successfully without errors
      assert rendered_html_string =~ "oli-multiple-choice-delivery"
      # The pageState should be present but empty (encoded as {})
      assert rendered_html_string =~ ~r/context=".*pageState.*"/
    end

    test "rewrites adaptive internal idref links to section lesson urls and opens in new tab", %{
      author: author
    } do
      adaptive_model = %{
        "partsLayout" => [
          %{
            "id" => "part_1",
            "type" => "janus-text-flow",
            "custom" => %{
              "nodes" => [
                %{
                  "tag" => "a",
                  "idref" => 22,
                  "children" => [%{"tag" => "text", "text" => "Go", "children" => []}]
                }
              ]
            }
          }
        ]
      }

      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{ \"active\": true }",
          model: Jason.encode!(adaptive_model) |> Oli.Delivery.Page.ActivityContext.encode(),
          delivery_element: "oli-adaptive-delivery",
          authoring_element: "oli-adaptive-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      element = %{"activity_id" => 1, "purpose" => "none"}

      rendered_html =
        Activity.render(
          %Context{
            user: author,
            section_slug: "my-section",
            page_link_params: [selected_view: "gallery"],
            activity_map: activity_map,
            resource_summary_fn: fn 22 ->
              %Oli.Rendering.Content.ResourceSummary{title: "T", slug: "target-page"}
            end
          },
          element,
          Activity.Html
        )

      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()
      [_, model_json] = Regex.run(~r/model="([^"]+)"/, rendered_html_string)
      {:ok, model} = model_json |> HtmlEntities.decode() |> Jason.decode()

      [part] = model["partsLayout"]
      [link] = part["custom"]["nodes"]

      assert link["href"] == "/sections/my-section/lesson/target-page?selected_view=gallery"
      assert link["target"] == "_blank"
    end

    test "falls back safely for unresolved adaptive idref links", %{author: author} do
      adaptive_model = %{
        "partsLayout" => [
          %{
            "id" => "part_1",
            "type" => "janus-text-flow",
            "custom" => %{
              "nodes" => [
                %{
                  "tag" => "a",
                  "idref" => 999,
                  "children" => [%{"tag" => "text", "text" => "Missing", "children" => []}]
                }
              ]
            }
          }
        ]
      }

      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{ \"active\": true }",
          model: Jason.encode!(adaptive_model) |> Oli.Delivery.Page.ActivityContext.encode(),
          delivery_element: "oli-adaptive-delivery",
          authoring_element: "oli-adaptive-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      element = %{"activity_id" => 1, "purpose" => "none"}

      assert capture_log(fn ->
               rendered_html =
                 Activity.render(
                   %Context{
                     user: author,
                     section_slug: "my-section",
                     page_link_params: [request_path: "/sections/my-section/lesson/current"],
                     activity_map: activity_map,
                     resource_summary_fn: fn _ -> raise "missing" end
                   },
                   element,
                   Activity.Html
                 )

               rendered_html_string =
                 Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

               [_, model_json] = Regex.run(~r/model="([^"]+)"/, rendered_html_string)
               {:ok, model} = model_json |> HtmlEntities.decode() |> Jason.decode()
               [part] = model["partsLayout"]
               [link] = part["custom"]["nodes"]

               assert link["href"] == "/sections/my-section/lesson/current"
               assert link["target"] == "_self"
             end) =~ "Unable to resolve adaptive dynamic link idref 999; using fallback"
    end

    test "rewrites adaptive internal href links with query/fragment to clean lesson slug", %{
      author: author
    } do
      adaptive_model = %{
        "partsLayout" => [
          %{
            "id" => "part_1",
            "type" => "janus-text-flow",
            "custom" => %{
              "nodes" => [
                %{
                  "tag" => "a",
                  "href" => "/course/link/target-page?x=1#y",
                  "children" => [%{"tag" => "text", "text" => "Go", "children" => []}]
                }
              ]
            }
          }
        ]
      }

      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{ \"active\": true }",
          model: Jason.encode!(adaptive_model) |> Oli.Delivery.Page.ActivityContext.encode(),
          delivery_element: "oli-adaptive-delivery",
          authoring_element: "oli-adaptive-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      rendered_html =
        Activity.render(
          %Context{
            user: author,
            section_slug: "my-section",
            page_link_params: [selected_view: "gallery"],
            activity_map: activity_map
          },
          %{"activity_id" => 1, "purpose" => "none"},
          Activity.Html
        )

      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()
      [_, model_json] = Regex.run(~r/model="([^"]+)"/, rendered_html_string)
      {:ok, model} = model_json |> HtmlEntities.decode() |> Jason.decode()

      [part] = model["partsLayout"]
      [link] = part["custom"]["nodes"]

      assert link["href"] == "/sections/my-section/lesson/target-page?selected_view=gallery"
      assert link["target"] == "_blank"
    end

    test "rewrites adaptive links when page_link_params is nil", %{author: author} do
      adaptive_model = %{
        "partsLayout" => [
          %{
            "id" => "part_1",
            "type" => "janus-text-flow",
            "custom" => %{
              "nodes" => [
                %{
                  "tag" => "a",
                  "idref" => 22,
                  "children" => [%{"tag" => "text", "text" => "Go", "children" => []}]
                }
              ]
            }
          }
        ]
      }

      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{ \"active\": true }",
          model: Jason.encode!(adaptive_model) |> Oli.Delivery.Page.ActivityContext.encode(),
          delivery_element: "oli-adaptive-delivery",
          authoring_element: "oli-adaptive-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      rendered_html =
        Activity.render(
          %Context{
            user: author,
            section_slug: "my-section",
            page_link_params: nil,
            activity_map: activity_map,
            resource_summary_fn: fn 22 ->
              %Oli.Rendering.Content.ResourceSummary{title: "T", slug: "target-page"}
            end
          },
          %{"activity_id" => 1, "purpose" => "none"},
          Activity.Html
        )

      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()
      [_, model_json] = Regex.run(~r/model="([^"]+)"/, rendered_html_string)
      {:ok, model} = model_json |> HtmlEntities.decode() |> Jason.decode()

      [part] = model["partsLayout"]
      [link] = part["custom"]["nodes"]

      assert link["href"] == "/sections/my-section/lesson/target-page"
      assert link["target"] == "_blank"
    end

    # @ac "AC-004"
    test "rewrites adaptive internal iframe idref sources to section lesson urls", %{
      author: author
    } do
      adaptive_model = %{
        "partsLayout" => [
          %{
            "id" => "part_iframe_1",
            "type" => "janus-capi-iframe",
            "src" => "/course/link/legacy-slug",
            "sourceType" => "page",
            "linkType" => "page",
            "idref" => 22
          }
        ]
      }

      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{ \"active\": true }",
          model: Jason.encode!(adaptive_model) |> Oli.Delivery.Page.ActivityContext.encode(),
          delivery_element: "oli-adaptive-delivery",
          authoring_element: "oli-adaptive-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      rendered_html =
        Activity.render(
          %Context{
            user: author,
            section_slug: "my-section",
            page_link_params: [selected_view: "gallery"],
            activity_map: activity_map,
            resource_summary_fn: fn 22 ->
              %Oli.Rendering.Content.ResourceSummary{title: "T", slug: "target-page"}
            end
          },
          %{"activity_id" => 1, "purpose" => "none"},
          Activity.Html
        )

      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()
      [_, model_json] = Regex.run(~r/model="([^"]+)"/, rendered_html_string)
      {:ok, model} = model_json |> HtmlEntities.decode() |> Jason.decode()

      [iframe_part] = model["partsLayout"]

      assert iframe_part["src"] ==
               "/sections/my-section/lesson/target-page?selected_view=gallery"

      refute Map.has_key?(iframe_part, "idref")
      refute Map.has_key?(iframe_part, "resource_id")
      refute Map.has_key?(iframe_part, "dynamicLinkFallback")
    end

    # @ac "AC-005"
    test "falls back safely for unresolved adaptive iframe sources while preserving other link rewrites",
         %{author: author} do
      adaptive_model = %{
        "partsLayout" => [
          %{
            "id" => "part_iframe_missing",
            "type" => "janus-capi-iframe",
            "src" => "/course/link/missing-page",
            "sourceType" => "page",
            "linkType" => "page",
            "idref" => 999
          },
          %{
            "id" => "part_text_ok",
            "type" => "janus-text-flow",
            "custom" => %{
              "nodes" => [
                %{
                  "tag" => "a",
                  "idref" => 22,
                  "children" => [%{"tag" => "text", "text" => "Ok", "children" => []}]
                }
              ]
            }
          }
        ]
      }

      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{ \"active\": true }",
          model: Jason.encode!(adaptive_model) |> Oli.Delivery.Page.ActivityContext.encode(),
          delivery_element: "oli-adaptive-delivery",
          authoring_element: "oli-adaptive-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      assert capture_log(fn ->
               rendered_html =
                 Activity.render(
                   %Context{
                     user: author,
                     section_slug: "my-section",
                     page_link_params: [request_path: "/sections/my-section/lesson/current"],
                     activity_map: activity_map,
                     resource_summary_fn: fn
                       22 ->
                         %Oli.Rendering.Content.ResourceSummary{title: "T", slug: "target-page"}

                       _ ->
                         raise "missing"
                     end
                   },
                   %{"activity_id" => 1, "purpose" => "none"},
                   Activity.Html
                 )

               rendered_html_string =
                 Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

               [_, model_json] = Regex.run(~r/model="([^"]+)"/, rendered_html_string)
               {:ok, model} = model_json |> HtmlEntities.decode() |> Jason.decode()

               iframe_part =
                 Enum.find(model["partsLayout"], fn part ->
                   part["id"] == "part_iframe_missing"
                 end)

               text_part =
                 Enum.find(model["partsLayout"], fn part -> part["id"] == "part_text_ok" end)

               [link] = text_part["custom"]["nodes"]

               assert iframe_part["src"] == "about:blank"
               assert iframe_part["dynamicLinkFallback"]["type"] == "unresolved_internal_source"

               assert iframe_part["dynamicLinkFallback"]["message"] ==
                        "This embedded page is unavailable."

               assert iframe_part["dynamicLinkFallback"]["href"] ==
                        "/sections/my-section/lesson/current"

               assert link["href"] ==
                        "/sections/my-section/lesson/target-page?request_path=%2Fsections%2Fmy-section%2Flesson%2Fcurrent"

               assert link["target"] == "_blank"
             end) =~ "Unable to resolve adaptive dynamic link idref 999; using fallback"
    end

    # @ac "AC-006"
    test "leaves external adaptive iframe urls untouched", %{author: author} do
      adaptive_model = %{
        "partsLayout" => [
          %{
            "id" => "part_iframe_external",
            "type" => "janus-capi-iframe",
            "src" => "https://example.com/embed",
            "sourceType" => "url"
          }
        ]
      }

      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{ \"active\": true }",
          model: Jason.encode!(adaptive_model) |> Oli.Delivery.Page.ActivityContext.encode(),
          delivery_element: "oli-adaptive-delivery",
          authoring_element: "oli-adaptive-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      rendered_html =
        Activity.render(
          %Context{
            user: author,
            section_slug: "my-section",
            page_link_params: [selected_view: "gallery"],
            activity_map: activity_map
          },
          %{"activity_id" => 1, "purpose" => "none"},
          Activity.Html
        )

      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()
      [_, model_json] = Regex.run(~r/model="([^"]+)"/, rendered_html_string)
      {:ok, model} = model_json |> HtmlEntities.decode() |> Jason.decode()

      [iframe_part] = model["partsLayout"]
      assert iframe_part["src"] == "https://example.com/embed"
      refute Map.has_key?(iframe_part, "dynamicLinkFallback")
    end

    test "memoizes adaptive link resolution per resource id within a render", %{author: author} do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      adaptive_model = %{
        "partsLayout" => [
          %{
            "id" => "part_1",
            "type" => "janus-text-flow",
            "custom" => %{
              "nodes" => [
                %{
                  "tag" => "a",
                  "idref" => 77,
                  "children" => [%{"tag" => "text", "text" => "One", "children" => []}]
                },
                %{
                  "tag" => "a",
                  "idref" => 77,
                  "children" => [%{"tag" => "text", "text" => "Two", "children" => []}]
                }
              ]
            }
          }
        ]
      }

      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{ \"active\": true }",
          model: Jason.encode!(adaptive_model) |> Oli.Delivery.Page.ActivityContext.encode(),
          delivery_element: "oli-adaptive-delivery",
          authoring_element: "oli-adaptive-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      _rendered_html =
        Activity.render(
          %Context{
            user: author,
            section_slug: "my-section",
            page_link_params: [],
            activity_map: activity_map,
            resource_summary_fn: fn 77 ->
              Agent.update(counter, &(&1 + 1))
              %Oli.Rendering.Content.ResourceSummary{title: "Memo", slug: "memo-page"}
            end
          },
          %{"activity_id" => 1, "purpose" => "none"},
          Activity.Html
        )

      assert Agent.get(counter, & &1) == 1
    end

    test "memoizes adaptive iframe source resolution per resource id within a render", %{
      author: author
    } do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      adaptive_model = %{
        "partsLayout" => [
          %{
            "id" => "part_iframe_1",
            "type" => "janus-capi-iframe",
            "src" => "/course/link/legacy-one",
            "sourceType" => "page",
            "idref" => 77
          },
          %{
            "id" => "part_iframe_2",
            "type" => "janus-capi-iframe",
            "src" => "/course/link/legacy-two",
            "sourceType" => "page",
            "idref" => 77
          }
        ]
      }

      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{ \"active\": true }",
          model: Jason.encode!(adaptive_model) |> Oli.Delivery.Page.ActivityContext.encode(),
          delivery_element: "oli-adaptive-delivery",
          authoring_element: "oli-adaptive-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      _rendered_html =
        Activity.render(
          %Context{
            user: author,
            section_slug: "my-section",
            page_link_params: [],
            activity_map: activity_map,
            resource_summary_fn: fn 77 ->
              Agent.update(counter, &(&1 + 1))
              %Oli.Rendering.Content.ResourceSummary{title: "Memo", slug: "memo-page"}
            end
          },
          %{"activity_id" => 1, "purpose" => "none"},
          Activity.Html
        )

      assert Agent.get(counter, & &1) == 1
    end

    test "emits adaptive dynamic-link telemetry for resolve and unresolved fallback", %{
      author: author
    } do
      handler = attach_telemetry([:resolved, :resolution_failed, :broken_clicked])

      adaptive_model = %{
        "partsLayout" => [
          %{
            "id" => "part_1",
            "type" => "janus-text-flow",
            "custom" => %{
              "nodes" => [
                %{
                  "tag" => "a",
                  "idref" => 22,
                  "children" => [%{"tag" => "text", "text" => "Ok"}]
                },
                %{
                  "tag" => "a",
                  "idref" => 999,
                  "children" => [%{"tag" => "text", "text" => "Bad"}]
                }
              ]
            }
          }
        ]
      }

      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{ \"active\": true }",
          model: Jason.encode!(adaptive_model) |> Oli.Delivery.Page.ActivityContext.encode(),
          delivery_element: "oli-adaptive-delivery",
          authoring_element: "oli-adaptive-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      _ =
        Activity.render(
          %Context{
            user: author,
            project_slug: "project-slug",
            section_slug: "my-section",
            page_link_params: [request_path: "/sections/my-section/lesson/current"],
            activity_map: activity_map,
            resource_summary_fn: fn
              22 -> %Oli.Rendering.Content.ResourceSummary{title: "T", slug: "target-page"}
              _ -> raise "missing"
            end
          },
          %{"activity_id" => 1, "purpose" => "none"},
          Activity.Html
        )

      assert_receive {:telemetry_event, [:oli, :adaptive, :dynamic_link, :resolved],
                      %{count: 1} = measurements, resolved_metadata}

      assert measurements.duration_ms >= 0
      assert resolved_metadata.project_slug == "project-slug"
      assert resolved_metadata.section_slug == "my-section"
      assert resolved_metadata.target_resource_id == 22
      assert resolved_metadata.reason == "resolved"

      assert_receive {:telemetry_event, [:oli, :adaptive, :dynamic_link, :resolution_failed],
                      %{count: 1}, failed_metadata}

      assert failed_metadata.target_resource_id == 999
      assert failed_metadata.reason in ["resource_not_found", "invalid_resource_id"]

      assert_receive {:telemetry_event, [:oli, :adaptive, :dynamic_link, :broken_clicked],
                      %{count: 1}, broken_metadata}

      assert broken_metadata.target_resource_id == 999
      assert broken_metadata.reason == "fallback_rendered"

      :telemetry.detach(handler)
    end

    # @ac "AC-009"
    test "emits iframe-specific adaptive dynamic-link telemetry metadata", %{author: author} do
      handler = attach_telemetry([:resolved, :resolution_failed, :broken_clicked])

      adaptive_model = %{
        "partsLayout" => [
          %{
            "id" => "iframe_resolved",
            "type" => "janus-capi-iframe",
            "src" => "/course/link/target-page",
            "sourceType" => "page",
            "linkType" => "page",
            "idref" => 22
          },
          %{
            "id" => "iframe_missing",
            "type" => "janus-capi-iframe",
            "src" => "/course/link/missing-page",
            "sourceType" => "page",
            "linkType" => "page",
            "idref" => 999
          }
        ]
      }

      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{ \"active\": true }",
          model: Jason.encode!(adaptive_model) |> Oli.Delivery.Page.ActivityContext.encode(),
          delivery_element: "oli-adaptive-delivery",
          authoring_element: "oli-adaptive-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      _ =
        Activity.render(
          %Context{
            user: author,
            project_slug: "project-slug",
            section_slug: "my-section",
            page_link_params: [request_path: "/sections/my-section/lesson/current"],
            activity_map: activity_map,
            resource_summary_fn: fn
              22 -> %Oli.Rendering.Content.ResourceSummary{title: "T", slug: "target-page"}
              _ -> raise "missing"
            end
          },
          %{"activity_id" => 1, "purpose" => "none"},
          Activity.Html
        )

      assert_receive {:telemetry_event, [:oli, :adaptive, :dynamic_link, :resolved], %{count: 1},
                      resolved_metadata}

      assert resolved_metadata.target_resource_id == 22
      assert resolved_metadata.reason == "resolved"
      assert resolved_metadata.source == "iframe_delivery_render"

      assert_receive {:telemetry_event, [:oli, :adaptive, :dynamic_link, :resolution_failed],
                      %{count: 1}, failed_metadata}

      assert failed_metadata.target_resource_id == 999
      assert failed_metadata.reason in ["resource_not_found", "invalid_resource_id"]
      assert failed_metadata.source == "iframe_delivery_render"

      assert_receive {:telemetry_event, [:oli, :adaptive, :dynamic_link, :broken_clicked],
                      %{count: 1}, broken_metadata}

      assert broken_metadata.target_resource_id == 999
      assert broken_metadata.reason == "fallback_rendered"
      assert broken_metadata.source == "iframe_delivery_render"

      :telemetry.detach(handler)
    end
  end

  defp attach_telemetry(events) do
    handler_id = "adaptive-html-telemetry-test-#{System.unique_integer([:positive])}"
    parent = self()

    telemetry_events =
      Enum.map(events, fn event ->
        [:oli, :adaptive, :dynamic_link, event]
      end)

    :ok =
      :telemetry.attach_many(
        handler_id,
        telemetry_events,
        fn event_name, measurements, metadata, _config ->
          send(parent, {:telemetry_event, event_name, measurements, metadata})
        end,
        nil
      )

    handler_id
  end
end
