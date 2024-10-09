defmodule OliWeb.Delivery.Student.Lesson.Components.OneAtATimeQuestionTest do
  use OliWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import LiveComponentTests

  alias OliWeb.Common.SessionContext
  alias OliWeb.Delivery.Student.Lesson.Components.OneAtATimeQuestion

  defp questions() do
    [
      %{
        state: %{
          "activityId" => 12742,
          "attemptGuid" => "bf97a652-6c83-4e1c-83d8-bf034f0eb140",
          "attemptNumber" => 1,
          "dateEvaluated" => nil,
          "dateSubmitted" => nil,
          "groupId" => nil,
          "hasMoreAttempts" => true,
          "lifecycle_state" => "active",
          "outOf" => nil,
          "parts" => [
            %{
              "attemptGuid" => "60d48247-cdfb-468c-bd95-8a3499be822f",
              "attemptNumber" => 1,
              "dateEvaluated" => nil,
              "dateSubmitted" => nil,
              "explanation" => nil,
              "feedback" => nil,
              "hasMoreAttempts" => true,
              "hasMoreHints" => false,
              "hints" => [],
              "outOf" => nil,
              "partId" => "1",
              "response" => nil,
              "score" => nil
            }
          ],
          "score" => nil
        },
        selected: true,
        context: %{
          "bibParams" => [],
          "graded" => true,
          "groupId" => nil,
          "isAnnotationLevel" => true,
          "learningLanguage" => nil,
          "pageAttemptGuid" => "3c7e510b-2c98-4157-93f7-e80ddbf651f6",
          "pageLinkParams" => %{
            "request_path" =>
              "/sections/elixir_20/lesson/one_question_at_a_time_graded_?request_path=%2Fsections%2Felixir_20%2Flearn%3Fselected_view%3Dgallery&selected_view=gallery",
            "selected_view" => "gallery"
          },
          "pageState" => %{},
          "projectSlug" => nil,
          "renderPointMarkers" => true,
          "sectionSlug" => "elixir_20",
          "showFeedback" => true,
          "surveyId" => nil,
          "userId" => 2,
          "variables" => %{}
        },
        number: 1,
        submitted: false,
        answered: false,
        part_points: %{"1" => 1},
        raw_content:
          "<oli-multiple-choice-delivery phx-update=\"ignore\" class=\"activity-container\" state=\"{&quot;parts&quot;:[{&quot;response&quot;:null,&quot;hints&quot;:[],&quot;score&quot;:null,&quot;feedback&quot;:null,&quot;explanation&quot;:null,&quot;attemptGuid&quot;:&quot;60d48247-cdfb-468c-bd95-8a3499be822f&quot;,&quot;attemptNumber&quot;:1,&quot;dateEvaluated&quot;:null,&quot;dateSubmitted&quot;:null,&quot;outOf&quot;:null,&quot;hasMoreAttempts&quot;:true,&quot;hasMoreHints&quot;:false,&quot;partId&quot;:&quot;1&quot;}],&quot;score&quot;:null,&quot;lifecycle_state&quot;:&quot;active&quot;,&quot;groupId&quot;:null,&quot;activityId&quot;:12742,&quot;attemptNumber&quot;:1,&quot;attemptGuid&quot;:&quot;bf97a652-6c83-4e1c-83d8-bf034f0eb140&quot;,&quot;outOf&quot;:null,&quot;dateEvaluated&quot;:null,&quot;dateSubmitted&quot;:null,&quot;hasMoreAttempts&quot;:true}\" model=\"{&quot;bibrefs&quot;:[],&quot;choices&quot;:[{&quot;content&quot;:[{&quot;children&quot;:[{&quot;text&quot;:&quot;Cho &quot;}],&quot;id&quot;:&quot;1786192605&quot;,&quot;type&quot;:&quot;p&quot;}],&quot;editor&quot;:&quot;slate&quot;,&quot;id&quot;:&quot;2781552450&quot;,&quot;textDirection&quot;:&quot;ltr&quot;},{&quot;content&quot;:[{&quot;children&quot;:[{&quot;text&quot;:&quot;Choice B&quot;}],&quot;id&quot;:&quot;1936475442&quot;,&quot;type&quot;:&quot;p&quot;}],&quot;editor&quot;:&quot;slate&quot;,&quot;id&quot;:&quot;3577885102&quot;,&quot;textDirection&quot;:&quot;ltr&quot;}],&quot;stem&quot;:{&quot;content&quot;:[{&quot;children&quot;:[{&quot;text&quot;:&quot;como es el numero magico&quot;}],&quot;id&quot;:&quot;2956973619&quot;,&quot;type&quot;:&quot;p&quot;}],&quot;editor&quot;:&quot;slate&quot;,&quot;id&quot;:&quot;3372078657&quot;,&quot;textDirection&quot;:&quot;ltr&quot;}}\" mode=\"delivery\" context=\"{&quot;surveyId&quot;:null,&quot;showFeedback&quot;:true,&quot;pageState&quot;:{},&quot;pageLinkParams&quot;:{&quot;selected_view&quot;:&quot;gallery&quot;,&quot;request_path&quot;:&quot;/sections/elixir_20/lesson/one_question_at_a_time_graded_?request_path=%2Fsections%2Felixir_20%2Flearn%3Fselected_view%3Dgallery&amp;selected_view=gallery&quot;},&quot;learningLanguage&quot;:null,&quot;bibParams&quot;:[],&quot;renderPointMarkers&quot;:true,&quot;isAnnotationLevel&quot;:true,&quot;pageAttemptGuid&quot;:&quot;3c7e510b-2c98-4157-93f7-e80ddbf651f6&quot;,&quot;groupId&quot;:null,&quot;userId&quot;:2,&quot;sectionSlug&quot;:&quot;elixir_20&quot;,&quot;projectSlug&quot;:null,&quot;graded&quot;:true,&quot;variables&quot;:{}}\" id=2e37cdfd-2132-4c30-a0b1-87a896179523></oli-multiple-choice-delivery>\n"
      },
      %{
        state: %{
          "activityId" => 12745,
          "attemptGuid" => "297c9198-aa6b-4e97-9a2e-f73c7dcd5d7b",
          "attemptNumber" => 1,
          "dateEvaluated" => nil,
          "dateSubmitted" => nil,
          "groupId" => nil,
          "hasMoreAttempts" => true,
          "lifecycle_state" => "active",
          "outOf" => nil,
          "parts" => [
            %{
              "attemptGuid" => "cbb0869a-2307-4be2-ab7f-273cc2a1eb87",
              "attemptNumber" => 1,
              "dateEvaluated" => nil,
              "dateSubmitted" => nil,
              "explanation" => nil,
              "feedback" => nil,
              "hasMoreAttempts" => true,
              "hasMoreHints" => false,
              "hints" => [],
              "outOf" => nil,
              "partId" => "1",
              "response" => nil,
              "score" => nil
            }
          ],
          "score" => nil
        },
        selected: false,
        context: %{
          "bibParams" => [],
          "graded" => true,
          "groupId" => nil,
          "isAnnotationLevel" => true,
          "learningLanguage" => nil,
          "pageAttemptGuid" => "3c7e510b-2c98-4157-93f7-e80ddbf651f6",
          "pageLinkParams" => %{
            "request_path" =>
              "/sections/elixir_20/lesson/one_question_at_a_time_graded_?request_path=%2Fsections%2Felixir_20%2Flearn%3Fselected_view%3Dgallery&selected_view=gallery",
            "selected_view" => "gallery"
          },
          "pageState" => %{},
          "projectSlug" => nil,
          "renderPointMarkers" => true,
          "sectionSlug" => "elixir_20",
          "showFeedback" => true,
          "surveyId" => nil,
          "userId" => 2,
          "variables" => %{}
        },
        number: 2,
        submitted: false,
        answered: false,
        part_points: %{"1" => 1},
        raw_content:
          "<oli-short-answer-delivery phx-update=\"ignore\" class=\"activity-container\" state=\"{&quot;parts&quot;:[{&quot;response&quot;:null,&quot;hints&quot;:[],&quot;score&quot;:null,&quot;feedback&quot;:null,&quot;explanation&quot;:null,&quot;attemptGuid&quot;:&quot;cbb0869a-2307-4be2-ab7f-273cc2a1eb87&quot;,&quot;attemptNumber&quot;:1,&quot;dateEvaluated&quot;:null,&quot;dateSubmitted&quot;:null,&quot;outOf&quot;:null,&quot;hasMoreAttempts&quot;:true,&quot;hasMoreHints&quot;:false,&quot;partId&quot;:&quot;1&quot;}],&quot;score&quot;:null,&quot;lifecycle_state&quot;:&quot;active&quot;,&quot;groupId&quot;:null,&quot;activityId&quot;:12745,&quot;attemptNumber&quot;:1,&quot;attemptGuid&quot;:&quot;297c9198-aa6b-4e97-9a2e-f73c7dcd5d7b&quot;,&quot;outOf&quot;:null,&quot;dateEvaluated&quot;:null,&quot;dateSubmitted&quot;:null,&quot;hasMoreAttempts&quot;:true}\" model=\"{&quot;bibrefs&quot;:[],&quot;inputType&quot;:&quot;numeric&quot;,&quot;stem&quot;:{&quot;content&quot;:[{&quot;children&quot;:[{&quot;text&quot;:&quot;1 + 5 = ?&quot;}],&quot;id&quot;:&quot;681117606&quot;,&quot;type&quot;:&quot;p&quot;}],&quot;editor&quot;:&quot;slate&quot;,&quot;id&quot;:&quot;3567089690&quot;,&quot;textDirection&quot;:&quot;ltr&quot;}}\" mode=\"delivery\" context=\"{&quot;surveyId&quot;:null,&quot;showFeedback&quot;:true,&quot;pageState&quot;:{},&quot;pageLinkParams&quot;:{&quot;selected_view&quot;:&quot;gallery&quot;,&quot;request_path&quot;:&quot;/sections/elixir_20/lesson/one_question_at_a_time_graded_?request_path=%2Fsections%2Felixir_20%2Flearn%3Fselected_view%3Dgallery&amp;selected_view=gallery&quot;},&quot;learningLanguage&quot;:null,&quot;bibParams&quot;:[],&quot;renderPointMarkers&quot;:true,&quot;isAnnotationLevel&quot;:true,&quot;pageAttemptGuid&quot;:&quot;3c7e510b-2c98-4157-93f7-e80ddbf651f6&quot;,&quot;groupId&quot;:null,&quot;userId&quot;:2,&quot;sectionSlug&quot;:&quot;elixir_20&quot;,&quot;projectSlug&quot;:null,&quot;graded&quot;:true,&quot;variables&quot;:{}}\" id=479f04af-284f-476d-b7db-1558f44defe6></oli-short-answer-delivery>\n"
      },
      %{
        state: %{
          "activityId" => 12746,
          "attemptGuid" => "1cb455dd-3930-4d01-9bc9-02b7e4673da6",
          "attemptNumber" => 1,
          "dateEvaluated" => nil,
          "dateSubmitted" => nil,
          "groupId" => nil,
          "hasMoreAttempts" => true,
          "lifecycle_state" => "active",
          "outOf" => nil,
          "parts" => [
            %{
              "attemptGuid" => "86ba2938-b74d-4a34-a6a8-323fac13a258",
              "attemptNumber" => 1,
              "dateEvaluated" => nil,
              "dateSubmitted" => nil,
              "explanation" => nil,
              "feedback" => nil,
              "hasMoreAttempts" => true,
              "hasMoreHints" => false,
              "hints" => [],
              "outOf" => nil,
              "partId" => "1",
              "response" => nil,
              "score" => nil
            },
            %{
              "attemptGuid" => "f315b04f-8f85-4afa-aed5-b6b64a5e6ff9",
              "attemptNumber" => 1,
              "dateEvaluated" => nil,
              "dateSubmitted" => nil,
              "explanation" => nil,
              "feedback" => nil,
              "hasMoreAttempts" => true,
              "hasMoreHints" => false,
              "hints" => [],
              "outOf" => nil,
              "partId" => "3660145108",
              "response" => nil,
              "score" => nil
            }
          ],
          "score" => nil
        },
        selected: false,
        context: %{
          "bibParams" => [],
          "graded" => true,
          "groupId" => nil,
          "isAnnotationLevel" => true,
          "learningLanguage" => nil,
          "pageAttemptGuid" => "3c7e510b-2c98-4157-93f7-e80ddbf651f6",
          "pageLinkParams" => %{
            "request_path" =>
              "/sections/elixir_20/lesson/one_question_at_a_time_graded_?request_path=%2Fsections%2Felixir_20%2Flearn%3Fselected_view%3Dgallery&selected_view=gallery",
            "selected_view" => "gallery"
          },
          "pageState" => %{},
          "projectSlug" => nil,
          "renderPointMarkers" => true,
          "sectionSlug" => "elixir_20",
          "showFeedback" => true,
          "surveyId" => nil,
          "userId" => 2,
          "variables" => %{}
        },
        number: 3,
        submitted: false,
        answered: false,
        part_points: %{"1" => 2.5, "3660145108" => 3.5},
        raw_content:
          "<oli-multi-input-delivery phx-update=\"ignore\" class=\"activity-container\" state=\"{&quot;parts&quot;:[{&quot;response&quot;:null,&quot;hints&quot;:[],&quot;score&quot;:null,&quot;feedback&quot;:null,&quot;explanation&quot;:null,&quot;attemptGuid&quot;:&quot;86ba2938-b74d-4a34-a6a8-323fac13a258&quot;,&quot;attemptNumber&quot;:1,&quot;dateEvaluated&quot;:null,&quot;dateSubmitted&quot;:null,&quot;outOf&quot;:null,&quot;hasMoreAttempts&quot;:true,&quot;hasMoreHints&quot;:false,&quot;partId&quot;:&quot;1&quot;},{&quot;response&quot;:null,&quot;hints&quot;:[],&quot;score&quot;:null,&quot;feedback&quot;:null,&quot;explanation&quot;:null,&quot;attemptGuid&quot;:&quot;f315b04f-8f85-4afa-aed5-b6b64a5e6ff9&quot;,&quot;attemptNumber&quot;:1,&quot;dateEvaluated&quot;:null,&quot;dateSubmitted&quot;:null,&quot;outOf&quot;:null,&quot;hasMoreAttempts&quot;:true,&quot;hasMoreHints&quot;:false,&quot;partId&quot;:&quot;3660145108&quot;}],&quot;score&quot;:null,&quot;lifecycle_state&quot;:&quot;active&quot;,&quot;groupId&quot;:null,&quot;activityId&quot;:12746,&quot;attemptNumber&quot;:1,&quot;attemptGuid&quot;:&quot;1cb455dd-3930-4d01-9bc9-02b7e4673da6&quot;,&quot;outOf&quot;:null,&quot;dateEvaluated&quot;:null,&quot;dateSubmitted&quot;:null,&quot;hasMoreAttempts&quot;:true}\" model=\"{&quot;bibrefs&quot;:[],&quot;choices&quot;:[],&quot;customScoring&quot;:true,&quot;inputs&quot;:[{&quot;id&quot;:&quot;2064744317&quot;,&quot;inputType&quot;:&quot;numeric&quot;,&quot;partId&quot;:&quot;1&quot;},{&quot;id&quot;:&quot;2198683801&quot;,&quot;inputType&quot;:&quot;numeric&quot;,&quot;partId&quot;:&quot;3660145108&quot;}],&quot;stem&quot;:{&quot;content&quot;:[{&quot;children&quot;:[{&quot;text&quot;:&quot;1 + 5 + 3 = &quot;},{&quot;children&quot;:[{&quot;text&quot;:&quot;&quot;}],&quot;id&quot;:&quot;2064744317&quot;,&quot;type&quot;:&quot;input_ref&quot;},{&quot;text&quot;:&quot;.&quot;}],&quot;id&quot;:&quot;2007335756&quot;,&quot;type&quot;:&quot;p&quot;},{&quot;children&quot;:[{&quot;text&quot;:&quot;&quot;}],&quot;id&quot;:&quot;2601568580&quot;,&quot;type&quot;:&quot;p&quot;},{&quot;children&quot;:[{&quot;text&quot;:&quot;2 + 5 + 8 = &quot;},{&quot;children&quot;:[{&quot;text&quot;:&quot;&quot;}],&quot;id&quot;:&quot;2198683801&quot;,&quot;type&quot;:&quot;input_ref&quot;},{&quot;text&quot;:&quot;&quot;}],&quot;id&quot;:&quot;2655767062&quot;,&quot;type&quot;:&quot;p&quot;}],&quot;id&quot;:&quot;1346478209&quot;},&quot;submitPerPart&quot;:false}\" mode=\"delivery\" context=\"{&quot;surveyId&quot;:null,&quot;showFeedback&quot;:true,&quot;pageState&quot;:{},&quot;pageLinkParams&quot;:{&quot;selected_view&quot;:&quot;gallery&quot;,&quot;request_path&quot;:&quot;/sections/elixir_20/lesson/one_question_at_a_time_graded_?request_path=%2Fsections%2Felixir_20%2Flearn%3Fselected_view%3Dgallery&amp;selected_view=gallery&quot;},&quot;learningLanguage&quot;:null,&quot;bibParams&quot;:[],&quot;renderPointMarkers&quot;:true,&quot;isAnnotationLevel&quot;:true,&quot;pageAttemptGuid&quot;:&quot;3c7e510b-2c98-4157-93f7-e80ddbf651f6&quot;,&quot;groupId&quot;:null,&quot;userId&quot;:2,&quot;sectionSlug&quot;:&quot;elixir_20&quot;,&quot;projectSlug&quot;:null,&quot;graded&quot;:true,&quot;variables&quot;:{}}\" id=0ce59fea-c4d9-45e4-8d7f-4d5136bc1de7></oli-multi-input-delivery>\n"
      }
    ]
  end

  defp update_question(component_params, question_number, question_params) do
    update_in(component_params, [:questions], fn questions ->
      Enum.map(questions, fn question ->
        if question.number == question_number do
          Map.merge(question, question_params)
        else
          question
        end
      end)
    end)
  end

  defp question_3_submitted() do
    %{
      submitted: true,
      anwered: true,
      state: %{
        "activityId" => 12746,
        "attemptGuid" => "1cb455dd-3930-4d01-9bc9-02b7e4673da6",
        "attemptNumber" => 1,
        "dateEvaluated" => nil,
        "dateSubmitted" => nil,
        "groupId" => nil,
        "hasMoreAttempts" => true,
        "lifecycle_state" => "active",
        "outOf" => nil,
        "parts" => [
          %{
            "attemptGuid" => "86ba2938-b74d-4a34-a6a8-323fac13a258",
            "attemptNumber" => 1,
            "dateEvaluated" => "2024-09-26T13:09:37Z",
            "dateSubmitted" => "2024-09-26T13:09:37Z",
            "explanation" => nil,
            "feedback" => %{
              "content" => [
                %{
                  "children" => [%{"text" => "Correct"}],
                  "id" => "2752881501",
                  "type" => "p"
                }
              ],
              "id" => "3131591610"
            },
            "hasMoreAttempts" => true,
            "hasMoreHints" => false,
            "hints" => [],
            "outOf" => 2.5,
            "partId" => "1",
            "response" => %{"files" => [], "input" => "9"},
            "score" => 2.5
          },
          %{
            "attemptGuid" => "f315b04f-8f85-4afa-aed5-b6b64a5e6ff9",
            "attemptNumber" => 1,
            "dateEvaluated" => "2024-09-26T13:09:37Z",
            "dateSubmitted" => "2024-09-26T13:09:37Z",
            "explanation" => nil,
            "feedback" => %{
              "content" => [
                %{
                  "children" => [%{"text" => "Incorrect"}],
                  "id" => "74189357",
                  "type" => "p"
                }
              ],
              "id" => "3090014517"
            },
            "hasMoreAttempts" => true,
            "hasMoreHints" => false,
            "hints" => [],
            "outOf" => 3.5,
            "partId" => "3660145108",
            "response" => %{"files" => [], "input" => "12"},
            "score" => 0.0
          }
        ],
        "score" => nil
      }
    }
  end

  describe "one at a time question component" do
    setup do
      {:ok,
       component_params: %{
         id: "the_component_id",
         questions: questions(),
         attempt_number: 1,
         max_attempt_number: 3,
         datashop_session_id: "f5c5622a-b2cd-4fec-9804-8b1feb6dcbb3",
         ctx: SessionContext.init() |> Map.put(:is_liveview, true),
         bib_app_params: %{},
         request_path: "/some_request_path",
         revision_slug: "some_revision_slug",
         attempt_guid: "bb39caf0-ba29-46e3-a1e8-35b1cf4bf7b0",
         section_slug: "some_section_slug"
       }}
    end

    test "is rendered correctly", %{conn: conn, component_params: component_params} do
      {:ok, lcd, _html} = live_component_isolated(conn, OneAtATimeQuestion, component_params)

      assert has_element?(lcd, "#the_component_id")
    end

    test "can be navigated through the questions menu or the footer buttons", %{
      conn: conn,
      component_params: component_params
    } do
      {:ok, lcd, _html} = live_component_isolated(conn, OneAtATimeQuestion, component_params)

      # initial state: current question button is disabled on menu

      assert lcd
             |> element("#question_1_button")
             |> render() =~ ~s{disabled="disabled"}

      refute lcd
             |> element("#question_2_button")
             |> render() =~ ~s{disabled="disabled"}

      refute lcd
             |> element("#question_3_button")
             |> render() =~ ~s{disabled="disabled"}

      # and previous button is disabled (since we are at the first question)

      assert lcd
             |> element("#previous_question_button")
             |> render() =~ ~s{disabled="disabled"}

      refute lcd
             |> element("#next_question_button")
             |> render() =~ ~s{disabled="disabled"}

      # We navigate to question 2 through the menu
      lcd
      |> element("#question_2_button")
      |> render_click()

      # initial state: question 2 button is disabled on menu
      refute lcd
             |> element("#question_1_button")
             |> render() =~ ~s{disabled="disabled"}

      assert lcd
             |> element("#question_2_button")
             |> render() =~ ~s{disabled="disabled"}

      refute lcd
             |> element("#question_3_button")
             |> render() =~ ~s{disabled="disabled"}

      # and previous button is enabled (since we are at the second question)

      refute lcd
             |> element("#previous_question_button")
             |> render() =~ ~s{disabled="disabled"}

      refute lcd
             |> element("#next_question_button")
             |> render() =~ ~s{disabled="disabled"}
    end

    test "shows the correct question points on the header", %{
      conn: conn,
      component_params: component_params
    } do
      {:ok, lcd, _html} = live_component_isolated(conn, OneAtATimeQuestion, component_params)

      assert lcd
             |> element("div[role='questions header']")
             |> render() =~ "Question 1 / 3 • 1 point"

      lcd
      |> element("#question_2_button")
      |> render_click()

      assert lcd
             |> element("div[role='questions header']")
             |> render() =~ "Question 2 / 3 • 1 point"

      lcd
      |> element("#question_3_button")
      |> render_click()

      assert lcd
             |> element("div[role='questions header']")
             |> render() =~ "Question 3 / 3 • 6.0 points"
    end

    test "shows the parts score summary for activities with more than 1 part", %{
      conn: conn,
      component_params: component_params
    } do
      {:ok, lcd, _html} = live_component_isolated(conn, OneAtATimeQuestion, component_params)

      refute has_element?(lcd, "div[role='parts score summary']")

      lcd
      |> element("#question_2_button")
      |> render_click()

      refute has_element?(lcd, "div[role='parts score summary']")

      lcd
      |> element("#question_3_button")
      |> render_click()

      assert has_element?(lcd, "div[role='parts score summary']")

      lcd
      |> element("div[role='parts score summary']")
      |> render() =~ "Part 1: 2.5 points"

      lcd
      |> element("div[role='parts score summary']")
      |> render() =~ "Part 2: 3.5 points"
    end

    test "the total points matches the sum of the part points", %{
      conn: conn,
      component_params: component_params
    } do
      {:ok, lcd, _html} = live_component_isolated(conn, OneAtATimeQuestion, component_params)

      lcd
      |> element("#question_3_button")
      |> render_click()

      # 2.5 + 3.5 = 6.0

      lcd
      |> element("div[role='parts score summary']")
      |> render() =~ "Part 1: 2.5 points"

      lcd
      |> element("div[role='parts score summary']")
      |> render() =~ "Part 2: 3.5 points"

      assert lcd
             |> element("div[role='questions header']")
             |> render() =~ "Question 3 / 3 • 6.0 points"
    end

    test "a submitted question renders the feedback and a not submitted does not", %{
      conn: conn,
      component_params: component_params
    } do
      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OneAtATimeQuestion,
          update_question(component_params, 3, question_3_submitted())
        )

      # question 1, not yet submitted, is selected by default
      refute has_element?(lcd, "div[role='question feedback']")

      lcd
      |> element("#question_3_button")
      |> render_click()

      assert lcd
             |> element("div[role='question points feedback']")
             |> render() =~ "2.5 / 6.0"

      assert has_element?(lcd, "div[role='question feedback']")
    end

    test "progress bar matches the amount of submitted questions", %{
      conn: conn,
      component_params: component_params
    } do
      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OneAtATimeQuestion,
          component_params
        )

      # 0.5% is the width of the progress bar when no question is submitted
      # (to match the Figma designs where a minimun width is set)
      assert lcd
             |> element(~s{div[role="progress bar"] div[role="progress"]})
             |> render()
             |> Floki.parse_fragment!()
             |> Floki.attribute("style") == ["width: 0.5%"]

      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OneAtATimeQuestion,
          update_question(component_params, 3, question_3_submitted())
        )

      # 1 out of 3 questions submitted => 33% of the progress bar
      assert lcd
             |> element(~s{div[role="progress bar"] div[role="progress"]})
             |> render()
             |> Floki.parse_fragment!()
             |> Floki.attribute("style") == ["width: 33.33333333333333%"]
    end

    test "modal warns the student when trying to finish the quiz with pending questions", %{
      conn: conn,
      component_params: component_params
    } do
      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OneAtATimeQuestion,
          component_params
        )

      assert lcd
             |> element("#finish_quiz_confirmation_modal")
             |> render() =~
               ~s{You are about to submit your attempt<span> with <strong>3</strong> unattempted questions</span>}

      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OneAtATimeQuestion,
          update_question(component_params, 3, question_3_submitted())
        )

      assert lcd
             |> element("#finish_quiz_confirmation_modal")
             |> render() =~
               ~s{You are about to submit your attempt<span> with <strong>2</strong> unattempted questions</span>}
    end

    test "finish quiz modal renders the correct attempts count", %{
      conn: conn,
      component_params: component_params
    } do
      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OneAtATimeQuestion,
          component_params
        )

      assert lcd
             |> element("#finish_quiz_confirmation_modal")
             |> render() =~ "Finish Attempt 1 of 3?"
    end
  end
end
