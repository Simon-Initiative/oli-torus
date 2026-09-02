defmodule Oli.Authoring.LearningObjectives.ProjectClassifierTest do
  use Oli.DataCase

  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.LearningObjectives.ProjectClassifier
  alias Oli.Repo
  alias Oli.Resources.ResourceType
  alias Oli.Seeder

  describe "well_formed?/1" do
    test "accepts top-level objectives on pages and sub-objectives on activities" do
      assert ProjectClassifier.well_formed?([
               objective_row(1, [2]),
               objective_row(2),
               content_row(:page, %{"attached" => [1]}),
               content_row(:activity, %{"part-1" => [2]})
             ])
    end

    test "rejects sub-objectives on pages" do
      refute ProjectClassifier.well_formed?([
               objective_row(1, [2]),
               objective_row(2),
               content_row(:page, %{"attached" => [2]})
             ])
    end

    test "rejects top-level objectives on activities" do
      refute ProjectClassifier.well_formed?([
               objective_row(1, [2]),
               objective_row(2),
               content_row(:activity, %{"part-1" => [1]})
             ])
    end

    test "rejects dangling objective references" do
      rows = [objective_row(1, [2]), objective_row(2)]

      refute ProjectClassifier.well_formed?([
               content_row(:page, %{"attached" => [999]}) | rows
             ])

      refute ProjectClassifier.well_formed?([
               content_row(:activity, %{"part-1" => [999]}) | rows
             ])
    end
  end

  describe "ensure_classified/2" do
    setup do
      map =
        Seeder.base_project_with_resource2()
        |> Seeder.add_objective("Sub-objective", :sub_objective)
        |> Seeder.add_objective_with_children("Top-level objective", [:sub_objective], :objective)

      project = set_classification(map.project, nil)

      {:ok, Map.put(map, :project, project)}
    end

    test "classifies and persists a well-formed working publication", map do
      parent_id = map.objective.resource.id
      child_id = map.sub_objective.resource.id

      revise_page_objectives(map, [parent_id])
      create_activity(map, [child_id])

      assert {:ok, true} =
               ProjectClassifier.ensure_classified(map.project, map.publication.id)

      assert Repo.get!(Project, map.project.id).lo_well_formed == true
    end

    test "classifies and persists a project with a sub-objective on a page", map do
      revise_page_objectives(map, [map.sub_objective.resource.id])

      assert {:ok, false} =
               ProjectClassifier.ensure_classified(map.project, map.publication.id)

      assert Repo.get!(Project, map.project.id).lo_well_formed == false
    end

    test "classifies and persists a project with a top-level objective on an activity", map do
      create_activity(map, [map.objective.resource.id])

      assert {:ok, false} =
               ProjectClassifier.ensure_classified(map.project, map.publication.id)

      assert Repo.get!(Project, map.project.id).lo_well_formed == false
    end

    test "ignores deleted content revisions", map do
      Seeder.create_activity(
        %{deleted: true, objectives: %{"part-1" => [map.objective.resource.id]}},
        map.publication,
        map.project,
        map.author
      )

      assert {:ok, true} =
               ProjectClassifier.ensure_classified(map.project, map.publication.id)
    end

    test "does not inspect or overwrite an existing classification", map do
      Enum.each([true, false], fn classification ->
        project = set_classification(map.project, classification)

        assert {:ok, ^classification} =
                 ProjectClassifier.ensure_classified(project, -1)

        assert Repo.get!(Project, project.id).lo_well_formed == classification
      end)
    end
  end

  defp objective_row(resource_id, children \\ []) do
    %{
      resource_id: resource_id,
      resource_type_id: ResourceType.id_for_objective(),
      children: children,
      objectives: %{}
    }
  end

  defp content_row(type, objectives) do
    %{
      resource_id: System.unique_integer([:positive]),
      resource_type_id: ResourceType.get_id_by_type(Atom.to_string(type)),
      children: [],
      objectives: objectives
    }
  end

  defp set_classification(project, value) do
    project
    |> Project.trusted_lo_well_formed_changeset(%{lo_well_formed: value})
    |> Repo.update!()
  end

  defp revise_page_objectives(map, objective_ids) do
    Seeder.revise_page(
      %{objectives: %{"attached" => objective_ids}},
      map.page1,
      map.revision1,
      map.publication
    )
  end

  defp create_activity(map, objective_ids) do
    Seeder.create_activity(
      %{objectives: %{"part-1" => objective_ids}},
      map.publication,
      map.project,
      map.author
    )
  end
end
