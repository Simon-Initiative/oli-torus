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
      assert rendered =~ ~s|<details class="group/proficiency learning-objectives-proficiency|
      assert rendered =~ "text-Text-text-low-alpha"
      assert rendered =~ "group-open/proficiency:rotate-180"
      assert rendered =~ "What is proficiency and how is it estimated?"
      assert rendered =~ "Proficiency estimates become more reliable"
      refute rendered =~ "Learning Objective Summary"
      refute rendered =~ "Review</h4>"
      refute rendered =~ "Practice</h4>"
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

    test "renders Summary proficiency labels, recommendations, and stale filtering" do
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
              40 => "Not enough data"
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
            "revisit_pages" => [101, 999, 201],
            "practice_pages" => [102]
          },
          %{
            "resource_id" => 11,
            "enabled" => true,
            "revisit_pages" => [],
            "practice_pages" => [104]
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
              section_resource(101, "Review page", "review-page", @page_type_id),
              section_resource(102, "Practice page", "practice-page", @page_type_id),
              section_resource(104, "Sub-objective practice", "sub-practice-page", @page_type_id),
              section_resource(201, "Container not page", "module", @container_type_id)
            ]
          end
        )
        |> safe_to_string()

      assert_received {:recommendations, 42, [101, 999, 201, 102, 104]}
      refute_received {:recommendations, _, _}

      assert rendered =~ "Learning Objective Summary"
      assert rendered =~ "Review limits"
      assert rendered =~ "Apply limit laws"
      assert rendered =~ "Practice derivatives"
      assert rendered =~ "Estimate integrals"
      assert rendered =~ "Analyze series"
      refute rendered =~ "Hidden objective"

      assert rendered =~ "Beginning Proficiency"
      assert rendered =~ "Growing Proficiency"
      assert rendered =~ "Strong Proficiency"
      assert rendered =~ "Not Enough Information"
      assert rendered =~ ~s|aria-label="Beginning Proficiency"|
      assert rendered =~ ~s|aria-label="Growing Proficiency"|
      assert rendered =~ ~s|aria-label="Strong Proficiency"|
      assert rendered =~ ~s|aria-label="Not Enough Information"|
      assert rendered =~ "text-Text-text-accent-green"

      assert rendered =~ ~s|role="tooltip"|
      refute rendered =~ "Not enough data"
      refute rendered =~ "Establishing Proficiency"

      assert rendered =~ "Review page"
      assert rendered =~ "Practice page"
      assert rendered =~ "Sub-objective practice"
      assert rendered =~ ~s|href="/sections/section-a/lesson/review-page"|
      refute rendered =~ "Container not page"
      refute rendered =~ ~s|href="/sections/section-a/lesson/999"|
      refute rendered =~ ">999<"
      refute rendered =~ ~s|href="/sections/section-a/lesson/103"|
      refute rendered =~ ">103<"
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

  defp context(learning_objectives) do
    %Context{
      learning_objectives: learning_objectives,
      section_id: 42,
      section_slug: "section-a",
      page_link_params: []
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

  defp section_resource(resource_id, title, slug, type_id) do
    %SectionResource{
      resource_id: resource_id,
      title: title,
      slug: slug,
      resource_type_id: type_id
    }
  end

  defp safe_to_string(iodata) do
    iodata
    |> HTML.raw()
    |> HTML.safe_to_string()
  end
end
