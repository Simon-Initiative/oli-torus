defmodule Oli.Rendering.Content.LearningObjectivesTest do
  use Oli.DataCase

  alias Oli.Delivery.LearningObjectives.IncludedObjective
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Rendering.Content
  alias Oli.Rendering.Content.LearningObjectives
  alias Oli.Rendering.Context
  alias Phoenix.HTML

  @page_type_id Oli.Resources.ResourceType.id_for_page()
  @container_type_id Oli.Resources.ResourceType.id_for_container()

  describe "HTML rendering" do
    test "renders Introduction heading, hierarchy, and collapsed proficiency explanation" do
      rendered =
        render_content(
          context(
            payload([
              objective(10, "Plan <Garden>", children: [11]),
              objective(11, "Identify sunlight", parent_resource_id: 10)
            ])
          ),
          %{
            "type" => "learning_objectives",
            "id" => "lo-intro",
            "mode" => "introduction",
            "include_sub_objectives" => true,
            "learning_objectives" => []
          }
        )

      assert rendered =~ "Learning Objectives"
      assert rendered =~ "Plan &lt;Garden&gt;"
      assert rendered =~ "Identify sunlight"
      assert rendered =~ "bg-Surface-surface-secondary"
      assert rendered =~ "bg-Surface-surface-primary"
      assert rendered =~ ~s|<div class="learning-objectives-delivery__objective-copy">|

      assert rendered =~
               ~s|<span class="learning-objectives-delivery__objective-number">LO 1</span>|

      assert rendered =~
               ~s|<span class="learning-objectives-delivery__objective-title">Plan &lt;Garden&gt;</span>|

      assert rendered =~ ~s|<ul class="learning-objectives-delivery__sub-objective-list">|

      assert rendered =~
               ~s|<li class="learning-objectives-delivery__sub-objective">Identify sunlight</li>|

      refute rendered =~ "learning-objectives-editor__sub-objective"

      assert rendered =~
               ~s|<details class="learning-objectives-editor__proficiency learning-objectives-proficiency">|

      assert rendered =~ ~s|<summary class="learning-objectives-editor__proficiency-summary|
      assert rendered =~ "What is proficiency and how is it estimated?"

      assert rendered =~
               "Proficiency estimates become more reliable as you complete more activities."

      assert rendered =~ "Beginning Proficiency"
      assert rendered =~ "Growing Proficiency"
      assert rendered =~ "Strong Proficiency"
      assert rendered =~ "Not Enough Information"
      assert rendered =~ "potted-plant-pattern"
      assert rendered =~ "potted-plant-image"
      assert rendered =~ "learning-objectives-editor__proficiency-card--unknown"
      assert rendered =~ "learning-objectives-editor__proficiency-card--beginning"
      assert rendered =~ "learning-objectives-editor__proficiency-card--growing"
      assert rendered =~ "learning-objectives-editor__proficiency-card--strong"
      refute rendered =~ "Learning Objective Summary"
      refute rendered =~ "Review</h4>"
      refute rendered =~ "Practice</h4>"
      refute rendered =~ "Sub-Objective"
    end

    test "honors Include Sub-Objectives per element" do
      rendered =
        render_content(
          context(
            payload([
              objective(10, "Plan Garden", children: [11]),
              objective(11, "Identify sunlight", parent_resource_id: 10)
            ])
          ),
          %{
            "type" => "learning_objectives",
            "id" => "lo-intro",
            "mode" => "introduction",
            "include_sub_objectives" => false,
            "learning_objectives" => []
          }
        )

      assert rendered =~ "Plan Garden"
      refute rendered =~ "Identify sunlight"
    end

    test "hides a disabled parent and its displayed sub-objectives" do
      rendered =
        render_content(
          context(
            payload([
              objective(10, "Plan Garden", children: [11]),
              objective(11, "Identify sunlight", parent_resource_id: 10)
            ])
          ),
          %{
            "type" => "learning_objectives",
            "id" => "lo-intro",
            "mode" => "introduction",
            "learning_objectives" => [
              %{"resource_id" => 10, "enabled" => false},
              %{"resource_id" => 11, "enabled" => true}
            ]
          }
        )

      assert rendered == ""
    end

    test "keeps a shared sub-objective visible through an enabled parent path" do
      rendered =
        render_content(
          context(
            payload([
              objective(10, "Disabled parent", children: [12]),
              objective(11, "Enabled parent", children: [12]),
              objective(12, "Shared sub-objective",
                parent_resource_id: 10,
                parent_resource_ids: [10, 11]
              )
            ])
          ),
          %{
            "type" => "learning_objectives",
            "id" => "lo-intro",
            "mode" => "introduction",
            "learning_objectives" => [
              %{"resource_id" => 10, "enabled" => false},
              %{"resource_id" => 11, "enabled" => true},
              %{"resource_id" => 12, "enabled" => true}
            ]
          }
        )

      refute rendered =~ "Disabled parent"
      assert rendered =~ "Enabled parent"
      assert rendered =~ "Shared sub-objective"
    end

    test "renders nothing when no objectives were discovered" do
      rendered =
        render_content(
          context(payload([])),
          %{"type" => "learning_objectives", "id" => "lo-empty", "mode" => "summary"}
        )

      assert rendered == ""
    end

    test "renders Summary base sections, proficiency labels, and next-step availability" do
      parent = self()

      context =
        context(
          payload(
            [
              objective(10, "Review limits", children: [11]),
              objective(11, "Apply limit laws", parent_resource_id: 10),
              objective(20, "Practice derivatives"),
              objective(30, "Hidden objective"),
              objective(40, "Estimate integrals"),
              objective(50, "Analyze series")
            ],
            performance_by_objective_id: %{
              10 => "Low",
              11 => "Medium",
              20 => "High",
              30 => "Medium",
              40 => "Not enough data",
              50 => "Medium"
            }
          )
        )

      element = %{
        "type" => "learning_objectives",
        "id" => "lo-summary",
        "mode" => "summary",
        "learning_objectives" => [
          %{
            "resource_id" => 10,
            "enabled" => true,
            "revisit_pages" => [101, 107, 999, 201],
            "practice_pages" => [102, 108]
          },
          %{
            "resource_id" => 11,
            "enabled" => true,
            "revisit_pages" => [],
            "practice_pages" => [104]
          },
          %{
            "resource_id" => 20,
            "enabled" => true,
            "revisit_pages" => [105],
            "practice_pages" => [106]
          },
          %{
            "resource_id" => 30,
            "enabled" => false,
            "revisit_pages" => [103],
            "practice_pages" => []
          }
        ]
      }

      rendered =
        context
        |> LearningObjectives.render(element,
          recommendation_resources_fun: fn section_id, resource_ids ->
            send(parent, {:recommendations, section_id, resource_ids})

            [
              section_resource(101, "Review page", "review-page", @page_type_id,
                revision_slug: "review-page-revision"
              ),
              section_resource(107, "Second review page", "second-review-page", @page_type_id),
              section_resource(102, "Practice page", "practice-page", @page_type_id),
              section_resource(
                108,
                "Second practice page",
                "second-practice-page",
                @page_type_id
              ),
              section_resource(104, "Sub-objective practice", "sub-practice-page", @page_type_id),
              section_resource(105, "Strong review page", "strong-review-page", @page_type_id),
              section_resource(
                106,
                "Strong practice page",
                "strong-practice-page",
                @page_type_id
              ),
              section_resource(201, "Container not page", "module", @container_type_id)
            ]
          end
        )
        |> safe_to_string()

      assert_received {:recommendations, 42, [101, 107, 999, 201, 102, 108, 104, 105, 106]}
      refute_received {:recommendations, _, _}

      assert rendered =~ "Learning Objectives"
      assert rendered =~ "Learning Objectives You're Applying"
      assert rendered =~ "Recommended Review"

      assert rendered =~
               "learning-objectives-summary__section learning-objectives-summary__section--applying border-Text-text-accent-green border bg-Surface-surface-secondary"

      assert rendered =~
               "learning-objectives-summary__section learning-objectives-summary__section--review border-Border-border-subtle border bg-Surface-surface-secondary"

      assert rendered =~ "learning-objectives-summary__card"
      refute rendered =~ "learning-objectives-summary__heading"
      assert rendered =~ ~s|data-next-steps="available"|
      assert rendered =~ ~s|<details class="learning-objectives-summary__next-steps">|
      assert rendered =~ "Show next steps"
      assert rendered =~ "Hide next steps"
      assert rendered =~ "<span>REVISIT</span>"
      assert rendered =~ "<span>PRACTICE</span>"
      refute rendered =~ "Need help understanding this objective?"
      refute rendered =~ "Explain this learning objective with DOT"
      assert rendered =~ "Review limits"
      assert rendered =~ "Apply limit laws"
      assert rendered =~ "Practice derivatives"
      refute rendered =~ "Estimate integrals"
      assert rendered =~ "Analyze series"
      refute rendered =~ "Hidden objective"

      assert rendered =~ "Beginning Proficiency"
      assert rendered =~ "Growing Proficiency"
      assert rendered =~ "Strong Proficiency"
      assert rendered =~ "Not Enough Information"
      assert rendered =~ "learning-objectives-summary__proficiency--beginning"
      assert rendered =~ "learning-objectives-summary__proficiency--growing"
      assert rendered =~ "learning-objectives-summary__proficiency--strong"
      refute rendered =~ "learning-objectives-summary__proficiency--unknown"
      assert rendered =~ "learning-objectives-summary__card--review-beginning"
      assert rendered =~ "learning-objectives-summary__card--review-growing"
      refute rendered =~ "learning-objectives-summary__card--review-unknown"
      assert rendered =~ "border-Fill-Accent-fill-accent-orange-bold"
      assert rendered =~ "border-Fill-Accent-fill-accent-purple-bold"
      refute rendered =~ "border-Text-text-low-alpha"
      assert rendered =~ "potted-plant-pattern"
      refute rendered =~ "Not enough data"
      refute rendered =~ "Sub-Objective"

      assert rendered =~ "Review page"
      assert rendered =~ "Second review page"
      assert rendered =~ "Practice page"
      assert rendered =~ "Second practice page"
      assert rendered =~ ~s|href="/sections/section-a/lesson/review-page-revision"|
      assert rendered =~ ~s|href="/sections/section-a/lesson/second-review-page"|
      assert rendered =~ ~s|href="/sections/section-a/lesson/practice-page"|
      assert rendered =~ ~s|href="/sections/section-a/lesson/second-practice-page"|
      refute rendered =~ "Sub-objective practice"
      refute rendered =~ "Container not page"
      refute rendered =~ "Strong review page"
      refute rendered =~ "Strong practice page"

      refute rendered =~ ~s|/lesson/999|
      refute rendered =~ ~s|/lesson/103|
    end

    test "renders Summary DOT explain card only when assistant is available" do
      element = %{
        "type" => "learning_objectives",
        "id" => "lo-summary",
        "mode" => "summary",
        "learning_objectives" => [
          %{
            "resource_id" => 10,
            "enabled" => true,
            "revisit_pages" => [101],
            "practice_pages" => []
          }
        ]
      }

      render = fn assistant_available? ->
        context(
          payload(
            [objective(10, "Review limits")],
            performance_by_objective_id: %{10 => "Low"}
          ),
          assistant_available?: assistant_available?
        )
        |> LearningObjectives.render(element,
          recommendation_resources_fun: fn _section_id, _resource_ids ->
            [section_resource(101, "Review page", "review-page", @page_type_id)]
          end
        )
        |> safe_to_string()
      end

      rendered_with_assistant = render.(true)
      rendered_without_assistant = render.(false)

      assert rendered_with_assistant =~ "Need help understanding this objective?"
      assert rendered_with_assistant =~ "Ask our AI Learning Assistant, DOT, to explain."
      assert rendered_with_assistant =~ "/images/assistant/footer_dot_ai.png"
      assert rendered_with_assistant =~ "Explain this learning objective with DOT"
      assert rendered_with_assistant =~ ~s|phx-hook="ExplainObjectiveButton"|
      assert rendered_with_assistant =~ ~s|data-section-slug="section-a"|
      assert rendered_with_assistant =~ ~s|data-objective-title="Review limits"|

      refute rendered_without_assistant =~ "Need help understanding this objective?"
      refute rendered_without_assistant =~ "Explain this learning objective with DOT"
    end

    test "does not render Summary DOT explain card for strong objectives" do
      rendered =
        context(
          payload(
            [
              objective(10, "Apply limit laws")
            ],
            performance_by_objective_id: %{10 => "High"}
          ),
          assistant_available?: true
        )
        |> LearningObjectives.render(
          %{
            "type" => "learning_objectives",
            "id" => "lo-summary",
            "mode" => "summary",
            "learning_objectives" => [
              %{
                "resource_id" => 10,
                "enabled" => true,
                "revisit_pages" => [101],
                "practice_pages" => [102]
              }
            ]
          },
          recommendation_resources_fun: fn _section_id, _resource_ids ->
            [
              section_resource(101, "Strong review page", "strong-review-page", @page_type_id),
              section_resource(102, "Strong practice page", "strong-practice-page", @page_type_id)
            ]
          end
        )
        |> safe_to_string()

      assert rendered =~ "Learning Objectives You're Applying"
      assert rendered =~ "Apply limit laws"
      refute rendered =~ "Show next steps"
      refute rendered =~ "Need help understanding this objective?"
      refute rendered =~ "Explain this learning objective with DOT"
    end

    test "does not render Summary next steps for review objectives without recommendations" do
      rendered =
        render_content(
          context(
            payload(
              [objective(10, "Review limits")],
              performance_by_objective_id: %{10 => "Low"}
            )
          ),
          %{
            "type" => "learning_objectives",
            "id" => "lo-summary",
            "mode" => "summary",
            "learning_objectives" => [
              %{
                "resource_id" => 10,
                "enabled" => true,
                "revisit_pages" => [],
                "practice_pages" => []
              }
            ]
          }
        )

      assert rendered =~ "Recommended Review"
      assert rendered =~ "Review limits"
      refute rendered =~ "Show next steps"
      refute rendered =~ "<span>REVISIT</span>"
      refute rendered =~ "<span>PRACTICE</span>"
      refute rendered =~ "Need help understanding this objective?"
    end
  end

  describe "text rendering" do
    test "renders compact plaintext and markdown text" do
      context = context(payload([objective(10, "Plan Garden")]))
      element = %{"type" => "learning_objectives", "mode" => "summary"}

      assert safe_to_string(Content.render(context, element, Content.Plaintext)) =~
               "Learning Objectives: Plan Garden"

      assert safe_to_string(Content.render(context, element, Content.Markdown)) =~
               "## Learning Objective Summary"
    end
  end

  defp render_content(context, element) do
    context
    |> Content.render(element, Content.Html)
    |> safe_to_string()
  end

  defp context(learning_objectives, opts \\ []) do
    %Context{
      learning_objectives: learning_objectives,
      section_id: 42,
      section_slug: "section-a",
      page_link_params: [],
      assistant_available?: Keyword.get(opts, :assistant_available?, false)
    }
  end

  defp payload(objectives, opts \\ []) do
    %{
      container_resource_id: 1,
      objectives: objectives,
      objectives_by_id: Map.new(objectives, &{&1.resource_id, &1}),
      performance_by_objective_id: Keyword.get(opts, :performance_by_objective_id, %{})
    }
  end

  defp objective(resource_id, title, opts \\ []) do
    %IncludedObjective{
      resource_id: resource_id,
      title: title,
      parent_resource_id: Keyword.get(opts, :parent_resource_id),
      parent_resource_ids: Keyword.get(opts, :parent_resource_ids, []),
      children: Keyword.get(opts, :children, [])
    }
  end

  defp section_resource(resource_id, title, slug, type_id, opts \\ []) do
    %SectionResource{
      resource_id: resource_id,
      title: title,
      slug: slug,
      revision_slug: Keyword.get(opts, :revision_slug),
      resource_type_id: type_id
    }
  end

  defp safe_to_string(iodata) do
    iodata
    |> HTML.raw()
    |> HTML.safe_to_string()
  end
end
