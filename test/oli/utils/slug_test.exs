defmodule Oli.Utils.SlugTest do

  use Oli.DataCase

  alias Oli.Utils.Slug

  alias Oli.Authoring.Course.Project
  alias Oli.Resources.Revision
  alias Oli.Repo
  alias Ecto.Changeset

  describe "resources" do

    setup do
      map = Seeder.base_project_with_resource2()

      # Create another project with resources and revisions
      Seeder.another_project(map.author, map.institution)

      map
    end

    test "alpha numeric only", _ do

      alpha_numeric = Slug.alpha_numeric_only("My_Test Project ~!@#$%^&*()--+=[]{}\|;:'<>,./?")
      assert alpha_numeric == "My_TestProject"

    end

    test "update_on_change/2 does not update the slug when the previous revision title matches", %{ revision1: r } do

      {:ok, new_revision} = Revision.changeset(%Revision{}, %{
        previous_revision_id: r.id,
        title: r.title,
        resource_id: r.resource_id,
        resource_type_id: r.resource_type_id,
        author_id: r.author_id
        })
      |> Repo.insert()

      assert new_revision.slug == r.slug

    end

    test "update_on_change/2 does update the slug when the previous revision title differs", %{ revision1: r } do

      {:ok, new_revision} = Revision.changeset(%Revision{}, %{
        previous_revision_id: r.id,
        title: "a different title",
        resource_id: r.resource_id,
        resource_type_id: r.resource_type_id,
        author_id: r.author_id
        })
      |> Repo.insert()

      refute new_revision.slug == r.slug
      assert new_revision.slug == "a_different_title"

    end

    test "update_on_change/2 handles the case when there isn't a previous revision", %{ revision1: r } do

      {:ok, new_revision} = Revision.changeset(%Revision{}, %{
        title: "a different title",
        resource_id: r.resource_id,
        resource_type_id: r.resource_type_id,
        author_id: r.author_id
        })
      |> Repo.insert()

      assert new_revision.slug == "a_different_title"

    end

    test "update_on_change/2 updates the slug when the title changes", %{ revision1: r } do

      # clearly a change that doesn't involve the title
      assert Revision.changeset(r, %{graded: true})
      |> Slug.update_on_change("revisions")
      |> Changeset.get_change(:slug) == nil

      # a change involving the title, but not actually changing it
      assert Revision.changeset(r, %{title: r.title})
      |> Slug.update_on_change("revisions")
      |> Changeset.get_change(:slug) == nil

      # changing the title
      assert Revision.changeset(r, %{title: "a changed title"})
      |> Slug.update_on_change("revisions")
      |> Changeset.get_change(:slug) == "a_changed_title"

      Revision.changeset(r, %{title: "a changed title"})
      |> Repo.update()

      r = Repo.get!(Revision, r.id)
      assert r.slug == "a_changed_title"

      Revision.changeset(r, %{title: "a changed title"})
      |> Repo.update()

      r = Repo.get!(Revision, r.id)
      assert r.slug == "a_changed_title"

    end

    test "update_never/2 does not update the slug when the title changes", %{ project: p } do

      assert Project.changeset(p, %{version: "2"})
      |> Slug.update_never("projects")
      |> Changeset.get_change(:slug) == nil

      assert Project.changeset(p, %{title: "a changed title"})
      |> Slug.update_never("projects")
      |> Changeset.get_change(:slug) == nil
    end

    test "update_on_change/2 produces valid slug when the title contains non-alphanumeric and special characters", %{ revision1: r } do

      {:ok, new_revision} = Revision.changeset(%Revision{}, %{
        previous_revision_id: r.id,
        title: "What’s in a Name?",   # apostrophe is a special character
        resource_id: r.resource_id,
        resource_type_id: r.resource_type_id,
        author_id: r.author_id
        })
      |> Repo.insert()

      refute new_revision.slug == r.slug
      assert new_revision.slug == "whats_in_a_name"

    end

  end


end
