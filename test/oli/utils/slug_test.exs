defmodule Oli.Utils.SlugTest do

  use Oli.DataCase

  alias Oli.Utils.Slug

  alias Oli.Authoring.Course.Project
  alias Oli.Resources.Revision

  alias Ecto.Changeset

  describe "resources" do

    setup do
      map = Seeder.base_project_with_resource2()

      # Create another project with resources and revisions
      Seeder.another_project(map.author, map.institution)

      map
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
      refute Revision.changeset(r, %{title: "a changed title"})
      |> Slug.update_on_change("revisions")
      |> Changeset.get_change(:slug) == nil

    end

    test "update_never/2 does not update the slug when the title changes", %{ project: p } do

      assert Project.changeset(p, %{version: "2"})
      |> Slug.update_never("projects")
      |> Changeset.get_change(:slug) == nil

      assert Project.changeset(p, %{title: "a changed title"})
      |> Slug.update_never("projects")
      |> Changeset.get_change(:slug) == nil
    end

  end


end
