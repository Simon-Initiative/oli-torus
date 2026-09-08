defmodule Oli.Scenarios.LearningObjectives.PageElementHooks do
  import ExUnit.Assertions

  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Delivery.LearningObjectives.PageElement, as: DeliveryPageElement
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Repo
  alias Oli.Rendering.Context
  alias Oli.Rendering.Content.LearningObjectives
  alias Oli.Resources
  alias Oli.Resources.Revision
  alias Oli.Scenarios.DirectiveTypes.ExecutionState
  alias Oli.Scenarios.Engine

  @project_name "lo_element_course"
  @section_name "lo_element_section"
  @student_name "learner"
  @objectives_page_title "Objectives Page"
  @practice_a_title "Practice A"
  @plain_page_title "Plain Page"
  @stale_objective_id 999_999
  @activity_ref_pages [
    {@practice_a_title, "slope_question"},
    {"Practice B", "intercept_question"}
  ]

  def sync_activity_ref_cache(%ExecutionState{} = state) do
    Enum.reduce(@activity_ref_pages, state, fn {page_title, virtual_id}, acc ->
      maybe_sync_activity_ref(acc, page_title, virtual_id)
    end)
  end

  def insert_summary_element(%ExecutionState{} = state) do
    built_project = fetch_project!(state)
    author = state.current_author
    page_revision = fetch_page_revision!(built_project, @objectives_page_title)
    practice_a_revision = fetch_page_revision!(built_project, @practice_a_title)
    slope_objective = fetch_objective!(built_project, "Compute slope")

    content = %{
      "version" => "0.1.0",
      "model" => [
        %{
          "type" => "content",
          "id" => "lo-intro-copy",
          "children" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Review the objectives for this unit."}]
            }
          ]
        },
        %{
          "type" => "learning_objectives",
          "id" => "unit-objectives-summary",
          "mode" => "summary",
          "include_sub_objectives" => true,
          "learning_objectives" => [
            %{
              "resource_id" => slope_objective.resource_id,
              "enabled" => true,
              "revisit_pages" => [page_revision.resource_id],
              "practice_pages" => [practice_a_revision.resource_id]
            },
            %{
              "resource_id" => @stale_objective_id,
              "enabled" => true,
              "revisit_pages" => [practice_a_revision.resource_id],
              "practice_pages" => []
            }
          ]
        }
      ]
    }

    assert PageEditor.acquire_lock(
             built_project.project.slug,
             page_revision.slug,
             author.email
           ) in [{:acquired}, {:updated}]

    assert {:ok, updated_revision} =
             PageEditor.edit(built_project.project.slug, page_revision.slug, author.email, %{
               "content" => content,
               "releaseLock" => true
             })

    assert learning_objectives_element?(updated_revision.content)

    put_page_revision(state, built_project, @objectives_page_title, updated_revision)
  end

  def assert_updated_authoring_and_delivery_state(%ExecutionState{} = state) do
    built_project = fetch_project!(state)
    section = fetch_section!(state)
    student = fetch_student!(state)

    objectives_page_revision =
      built_project
      |> fetch_page_revision!(@objectives_page_title)
      |> current_working_revision!(built_project)

    plain_page_revision = fetch_page_revision!(built_project, @plain_page_title)

    assert {:ok, authoring_context} =
             PageEditor.create_context(
               built_project.project.slug,
               objectives_page_revision.slug,
               state.current_author
             )

    assert learning_objectives_element?(objectives_page_revision.content)

    assert authoring_context.learningObjectives |> titles() |> Enum.sort() ==
             ["Compute slope", "Interpret intercepts"]

    delivery_revision = section_revision!(section, objectives_page_revision.resource_id)

    payload =
      DeliveryPageElement.prepare_render_payload(
        section,
        objectives_page_revision.resource_id,
        delivery_revision.content,
        student
      )

    assert payload.objectives |> titles() |> Enum.sort() == [
             "Compute slope",
             "Interpret intercepts"
           ]

    refute Map.has_key?(payload.objectives_by_id, @stale_objective_id)

    element =
      Enum.find(delivery_revision.content["model"], &(&1["type"] == "learning_objectives"))

    html =
      %Context{
        section_id: section.id,
        section_slug: section.slug,
        user: student,
        learning_objectives: payload,
        internal_link_url: fn slug -> "/sections/#{section.slug}/lesson/#{slug}" end
      }
      |> LearningObjectives.render(element)
      |> IO.iodata_to_binary()

    # Both objectives lack enough attempts for a reliable proficiency signal (< 3 first attempts),
    # so D9 filtering excludes them from the summary entirely.
    refute html =~ "Compute slope"
    refute html =~ "Interpret intercepts"
    refute html =~ "Objectives Page"
    refute html =~ "Practice A"
    refute html =~ "Practice B</a>"
    refute html =~ Integer.to_string(@stale_objective_id)

    plain_delivery_revision = section_revision!(section, plain_page_revision.resource_id)

    assert DeliveryPageElement.prepare_render_payload(
             section,
             plain_page_revision.resource_id,
             plain_delivery_revision.content,
             student
           ) == nil

    state
  end

  defp fetch_project!(%ExecutionState{} = state) do
    Engine.get_project(state, @project_name) || raise "Project #{@project_name} not found"
  end

  defp fetch_section!(%ExecutionState{} = state) do
    Engine.get_section(state, @section_name) || raise "Section #{@section_name} not found"
  end

  defp fetch_student!(%ExecutionState{} = state) do
    Engine.get_user(state, @student_name) || raise "Student #{@student_name} not found"
  end

  defp fetch_page_revision!(built_project, title) do
    Map.get(built_project.rev_by_title, title) || raise "Page #{title} not found"
  end

  defp fetch_objective!(built_project, title) do
    Map.get(built_project.objectives_by_title, title) || raise "Objective #{title} not found"
  end

  defp maybe_sync_activity_ref(%ExecutionState{} = state, page_title, virtual_id) do
    built_project = fetch_project!(state)
    activity_revision = Map.get(state.activity_virtual_ids, {@project_name, virtual_id})
    page_revision = Map.get(built_project.rev_by_title, page_title)

    if is_nil(activity_revision) || is_nil(page_revision) do
      state
    else
      sync_activity_ref!(state, built_project, page_title, page_revision, activity_revision)
    end
  end

  defp sync_activity_ref!(state, built_project, page_title, page_revision, activity_revision) do
    page_revision = current_working_revision!(page_revision, built_project)

    activity_refs =
      Enum.uniq(List.wrap(page_revision.activity_refs) ++ [activity_revision.resource_id])

    if page_revision.activity_refs == activity_refs do
      state
    else
      # Scenario edit_page currently writes activity-reference content without updating the
      # revision.activity_refs cache. The browser PageEditor path does maintain this cache,
      # and both authoring and delivery discovery deliberately depend on it for bounded scans.
      assert {:ok, updated_revision} =
               Resources.update_revision(page_revision, %{
                 author_id: state.current_author.id,
                 activity_refs: activity_refs
               })

      case Publishing.project_working_publication(built_project.project.slug) do
        nil -> :ok
        publication -> Publishing.upsert_published_resource(publication, updated_revision)
      end

      put_page_revision(state, built_project, page_title, updated_revision)
    end
  end

  defp put_page_revision(state, built_project, title, updated_revision) do
    updated_project = %{
      built_project
      | rev_by_title: Map.put(built_project.rev_by_title, title, updated_revision)
    }

    Engine.put_project(state, @project_name, updated_project)
  end

  defp current_working_revision!(revision, built_project) do
    AuthoringResolver.from_resource_id(built_project.project.slug, revision.resource_id) ||
      raise "Current working revision #{revision.resource_id} not found"
  end

  defp section_revision!(section, resource_id) do
    case SectionResourceDepot.get_section_resource(section.id, resource_id) do
      nil ->
        raise "Section resource #{resource_id} not found"

      section_resource ->
        Repo.get!(Revision, section_resource.revision_id)
    end
  end

  defp titles(items), do: Enum.map(items, & &1.title)

  defp learning_objectives_element?(%{"model" => model}) when is_list(model) do
    Enum.any?(model, &match?(%{"type" => "learning_objectives"}, &1))
  end

  defp learning_objectives_element?(_), do: false
end
