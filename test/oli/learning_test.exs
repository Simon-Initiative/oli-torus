defmodule Oli.LearningTest do
  use Oli.DataCase

  alias Oli.Learning


  alias Oli.Accounts.SystemRole
  alias Oli.Accounts.Institution
  alias Oli.Accounts.Author
  alias Oli.Course.Project
  alias Oli.Course.Family
  alias Oli.Publishing.Publication
  alias Oli.Learning.Objective
  alias Oli.Learning.ObjectiveRevision

  describe "objectives" do
    alias Oli.Learning.Objective

    @valid_attrs %{slug: "some slug"}
    @update_attrs %{slug: "some updated slug"}
    @invalid_attrs %{slug: nil}

    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert

      {:ok, objective} = Objective.changeset(%Objective{}, %{slug: "slug", project_id: project.id}) |> Repo.insert

      valid_attrs = Map.put(@valid_attrs, :project_id, project.id)

      {:ok, %{objective: objective, valid_attrs: valid_attrs}}
    end

    test "list_objectives/0 returns all objectives", %{objective: objective} do
      assert Learning.list_objectives() == [objective]
    end

    test "get_objective!/1 returns the objective with given id", %{objective: objective} do
      assert Learning.get_objective!(objective.id) == objective
    end

    test "create_objective/1 with valid data creates a objective", %{valid_attrs: valid_attrs} do
      assert {:ok, %Objective{} = objective} = Learning.create_objective(valid_attrs)
      assert objective.slug == "some slug"
    end

    test "create_objective/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Learning.create_objective(@invalid_attrs)
    end

    test "update_objective/2 with valid data updates the objective", %{objective: objective} do
      assert {:ok, %Objective{} = objective} = Learning.update_objective(objective, @update_attrs)
      assert objective.slug == "some updated slug"
    end

    test "update_objective/2 with invalid data returns error changeset", %{objective: objective} do
      assert {:error, %Ecto.Changeset{}} = Learning.update_objective(objective, @invalid_attrs)
      assert objective == Learning.get_objective!(objective.id)
    end

    test "delete_objective/1 deletes the objective", %{objective: objective} do
      assert {:ok, %Objective{}} = Learning.delete_objective(objective)
      assert_raise Ecto.NoResultsError, fn -> Learning.get_objective!(objective.id) end
    end

    test "change_objective/1 returns a objective changeset", %{objective: objective} do
      assert %Ecto.Changeset{} = Learning.change_objective(objective)
    end
  end

  describe "objective_revisions" do
    alias Oli.Learning.ObjectiveRevision

    @valid_attrs %{title: "some title", children: [], deleted: false}
    @update_attrs %{title: "some updated title", children: [], deleted: true}
    @invalid_attrs %{title: nil, children: nil, deleted: nil}

    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, _publication} = Publication.changeset(%Publication{}, %{description: "description", published: False, root_resources: [], project_id: project.id}) |> Repo.insert
      {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: SystemRole.role_id.author}) |> Repo.insert
      {:ok, _institution} = Institution.changeset(%Institution{}, %{name: "CMU", country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", timezone: "some timezone", consumer_key: "some key", shared_secret: "some secret", author_id: author.id}) |> Repo.insert
      {:ok, objective} = Objective.changeset(%Objective{}, %{slug: "slug", project_id: project.id}) |> Repo.insert

      valid_attrs = Map.put(@valid_attrs, :objective_id, objective.id)

      {:ok, revision} = valid_attrs |> Learning.create_objective_revision()

      {:ok, %{objective_revision: revision, valid_attrs: valid_attrs}}
    end

    test "list_objective_revisions/0 returns all objective_revisions", %{objective_revision: objective_revision} do
      assert Learning.list_objective_revisions() == [objective_revision]
    end

    test "get_objective_revision!/1 returns the objective_revision with given id", %{objective_revision: objective_revision} do
      assert Learning.get_objective_revision!(objective_revision.id) == objective_revision
    end

    test "create_objective_revision/1 with valid data creates a objective_revision", %{valid_attrs: valid_attrs} do
      assert {:ok, %ObjectiveRevision{} = objective_revision} = Learning.create_objective_revision(valid_attrs)
      assert objective_revision.title == "some title"
    end

    test "create_objective_revision/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Learning.create_objective_revision(@invalid_attrs)
    end

    test "update_objective_revision/2 with valid data updates the objective_revision", %{objective_revision: objective_revision} do
      assert {:ok, %ObjectiveRevision{} = objective_revision} = Learning.update_objective_revision(objective_revision, @update_attrs)
      assert objective_revision.title == "some updated title"
    end

    test "update_objective_revision/2 with invalid data returns error changeset", %{objective_revision: objective_revision} do
      assert {:error, %Ecto.Changeset{}} = Learning.update_objective_revision(objective_revision, @invalid_attrs)
      assert objective_revision == Learning.get_objective_revision!(objective_revision.id)
    end

    test "delete_objective_revision/1 deletes the objective_revision", %{objective_revision: objective_revision} do
      assert {:ok, %ObjectiveRevision{}} = Learning.delete_objective_revision(objective_revision)
      assert_raise Ecto.NoResultsError, fn -> Learning.get_objective_revision!(objective_revision.id) end
    end

    test "change_objective_revision/1 returns a objective_revision changeset", %{objective_revision: objective_revision} do
      assert %Ecto.Changeset{} = Learning.change_objective_revision(objective_revision)
    end
  end
end
