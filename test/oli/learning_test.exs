defmodule Oli.LearningTest do
  use Oli.DataCase

  alias Oli.Learning

  describe "objectives" do
    alias Oli.Learning.Objective

    @valid_attrs %{slug: "some slug"}
    @update_attrs %{slug: "some updated slug"}
    @invalid_attrs %{slug: nil}

    def objective_fixture(attrs \\ %{}) do
      {:ok, objective} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Learning.create_objective()

      objective
    end

    test "list_objectives/0 returns all objectives" do
      objective = objective_fixture()
      assert Learning.list_objectives() == [objective]
    end

    test "get_objective!/1 returns the objective with given id" do
      objective = objective_fixture()
      assert Learning.get_objective!(objective.id) == objective
    end

    test "create_objective/1 with valid data creates a objective" do
      assert {:ok, %Objective{} = objective} = Learning.create_objective(@valid_attrs)
      assert objective.slug == "some slug"
    end

    test "create_objective/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Learning.create_objective(@invalid_attrs)
    end

    test "update_objective/2 with valid data updates the objective" do
      objective = objective_fixture()
      assert {:ok, %Objective{} = objective} = Learning.update_objective(objective, @update_attrs)
      assert objective.slug == "some updated slug"
    end

    test "update_objective/2 with invalid data returns error changeset" do
      objective = objective_fixture()
      assert {:error, %Ecto.Changeset{}} = Learning.update_objective(objective, @invalid_attrs)
      assert objective == Learning.get_objective!(objective.id)
    end

    test "delete_objective/1 deletes the objective" do
      objective = objective_fixture()
      assert {:ok, %Objective{}} = Learning.delete_objective(objective)
      assert_raise Ecto.NoResultsError, fn -> Learning.get_objective!(objective.id) end
    end

    test "change_objective/1 returns a objective changeset" do
      objective = objective_fixture()
      assert %Ecto.Changeset{} = Learning.change_objective(objective)
    end
  end

  describe "objective_revisions" do
    alias Oli.Learning.ObjectiveRevision

    @valid_attrs %{title: "some title"}
    @update_attrs %{title: "some updated title"}
    @invalid_attrs %{title: nil}

    def objective_revision_fixture(attrs \\ %{}) do
      {:ok, objective_revision} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Learning.create_objective_revision()

      objective_revision
    end

    test "list_objective_revisions/0 returns all objective_revisions" do
      objective_revision = objective_revision_fixture()
      assert Learning.list_objective_revisions() == [objective_revision]
    end

    test "get_objective_revision!/1 returns the objective_revision with given id" do
      objective_revision = objective_revision_fixture()
      assert Learning.get_objective_revision!(objective_revision.id) == objective_revision
    end

    test "create_objective_revision/1 with valid data creates a objective_revision" do
      assert {:ok, %ObjectiveRevision{} = objective_revision} = Learning.create_objective_revision(@valid_attrs)
      assert objective_revision.title == "some title"
    end

    test "create_objective_revision/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Learning.create_objective_revision(@invalid_attrs)
    end

    test "update_objective_revision/2 with valid data updates the objective_revision" do
      objective_revision = objective_revision_fixture()
      assert {:ok, %ObjectiveRevision{} = objective_revision} = Learning.update_objective_revision(objective_revision, @update_attrs)
      assert objective_revision.title == "some updated title"
    end

    test "update_objective_revision/2 with invalid data returns error changeset" do
      objective_revision = objective_revision_fixture()
      assert {:error, %Ecto.Changeset{}} = Learning.update_objective_revision(objective_revision, @invalid_attrs)
      assert objective_revision == Learning.get_objective_revision!(objective_revision.id)
    end

    test "delete_objective_revision/1 deletes the objective_revision" do
      objective_revision = objective_revision_fixture()
      assert {:ok, %ObjectiveRevision{}} = Learning.delete_objective_revision(objective_revision)
      assert_raise Ecto.NoResultsError, fn -> Learning.get_objective_revision!(objective_revision.id) end
    end

    test "change_objective_revision/1 returns a objective_revision changeset" do
      objective_revision = objective_revision_fixture()
      assert %Ecto.Changeset{} = Learning.change_objective_revision(objective_revision)
    end
  end
end
