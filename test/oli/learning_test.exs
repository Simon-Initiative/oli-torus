defmodule Oli.LearningTest do
  use Oli.DataCase

  alias Oli.Accounts.{SystemRole, Institution, Author}
  alias Oli.Authoring.Course.{Project, Family}
  alias Oli.Authoring.Learning
  alias Oli.Authoring.Learning.{Objective, ObjectiveFamily}
  alias Oli.Authoring.Resources.{Resource, ResourceFamily}
  alias Oli.Publishing.Publication

  describe "objectives" do

    @valid_attrs %{slug: "some slug"}
    # @update_attrs %{slug: "some updated slug"}
    # @invalid_attrs %{slug: nil}

    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, objective_family} = ObjectiveFamily.changeset(%ObjectiveFamily{}, %{}) |> Repo.insert
      {:ok, objective} = Objective.changeset(%Objective{}, %{family_id: objective_family.id, project_id: project.id}) |> Repo.insert

      valid_attrs = Map.put(@valid_attrs, :project_id, project.id)

      {:ok, %{objective: objective, project: project, family: objective_family, valid_attrs: valid_attrs}}
    end

    test "get_objective!/1 returns the objective with given id", %{objective: objective} do
      assert Learning.get_objective!(objective.id) == objective
    end

    test "delete_objective/1 deletes the objective", %{objective: objective} do
      assert {:ok, %Objective{}} = Learning.delete_objective(objective)
      assert_raise Ecto.NoResultsError, fn -> Learning.get_objective!(objective.id) end
    end
  end

  describe "objective_revisions" do

    @valid_attrs %{title: "some title", children: [], deleted: false}
    # @update_attrs %{title: "some updated title", children: [], deleted: true}
    # @invalid_attrs %{title: nil, children: nil, deleted: nil}

    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, resource_family} = ResourceFamily.changeset(%ResourceFamily{}, %{}) |> Repo.insert
      {:ok, resource} = Resource.changeset(%Resource{}, %{project_id: project.id, family_id: resource_family.id}) |> Repo.insert
      {:ok, _publication} = Publication.changeset(%Publication{}, %{description: "description", published: false, root_resource_id: resource.id, project_id: project.id}) |> Repo.insert
      {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: SystemRole.role_id.author}) |> Repo.insert
      {:ok, _institution} = Institution.changeset(%Institution{}, %{name: "CMU", country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", timezone: "some timezone", consumer_key: "some key", shared_secret: "some secret", author_id: author.id}) |> Repo.insert
      {:ok, objective_family} = ObjectiveFamily.changeset(%ObjectiveFamily{}, %{}) |> Repo.insert
      {:ok, objective} = Objective.changeset(%Objective{}, %{family_id: objective_family.id, project_id: project.id}) |> Repo.insert

      valid_attrs = Map.put(@valid_attrs, :objective_id, objective.id)

      {:ok, revision} = valid_attrs |> Learning.create_objective_revision()

      {:ok, %{objective_revision: revision, valid_attrs: valid_attrs}}
    end
  end
end
