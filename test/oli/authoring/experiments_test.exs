defmodule Oli.Authoring.ExperimentsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Authoring.Experiments
  alias Oli.Resources.ResourceType

  @alternatives_type_id ResourceType.id_for_alternatives()
  @container_type_id ResourceType.id_for_container()
  @experiment_id "upgrade_decision_point"
  @another_id "another_id"

  describe "get_latest_experiment/1" do
    test "returns revision (experiment) for a given project slug" do
      project = insert(:project, slug: "some_project")
      publication = insert(:publication, project: project, published: nil)
      content = %{"strategy" => @experiment_id}
      revision = insert(:revision, content: content, resource_type_id: @alternatives_type_id)
      insert(:published_resource, revision: revision, publication: publication)

      assert %Oli.Resources.Revision{content: %{"strategy" => @experiment_id}} =
               Experiments.get_latest_experiment(project.slug)
    end

    test "returns nil when not in the current publication" do
      project = insert(:project, slug: "some_project")
      publication = insert(:publication, project: project)
      content = %{"strategy" => @experiment_id}
      revision = insert(:revision, content: content, resource_type_id: @alternatives_type_id)
      insert(:published_resource, revision: revision, publication: publication)

      assert nil == Experiments.get_latest_experiment(project.slug)
    end

    test "returns nil when strategy is different to upgrade_decision_point" do
      project = insert(:project, slug: "some_project")
      publication = insert(:publication, project: project, published: nil)
      content = %{"strategy" => @another_id}
      revision = insert(:revision, content: content, resource_type_id: @alternatives_type_id)
      insert(:published_resource, revision: revision, publication: publication)

      assert nil == Experiments.get_latest_experiment(project.slug)
    end

    test "returns nil when resource_type_id is different to alternatives_type_id" do
      project = insert(:project, slug: "some_project")
      publication = insert(:publication, project: project, published: nil)
      content = %{"strategy" => @experiment_id}
      revision = insert(:revision, content: content, resource_type_id: @container_type_id)
      insert(:published_resource, revision: revision, publication: publication)

      assert nil == Experiments.get_latest_experiment(project.slug)
    end
  end
end
