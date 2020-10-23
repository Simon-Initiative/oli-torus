defmodule Oli.Authoring.IngestTest do

  alias Oli.Authoring.Ingest
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.Revision
  alias Oli.Repo
  use Oli.DataCase

  def by_title(project, title) do
    query = from r in Revision,
          where: r.title == ^title,
          limit: 1
    AuthoringResolver.from_revision_slug(project.slug, Repo.one(query).slug)
  end

  describe "course project ingest" do

    setup do
      Oli.Seeder.base_project_with_resource2()
    end

    test "ingest/1 processes the digest and creates a course", %{author: author} do

      {:ok, p} = Ingest.ingest("./test/oli/authoring/course.zip", author)

      # verify project
      project = Repo.get(Oli.Authoring.Course.Project, p.id)
      assert project.title == "KTH CS101"
      assert p.title == project.title

      # verify project access for author
      access = Repo.get_by(Oli.Authoring.Authors.AuthorProject, [author_id: author.id, project_id: project.id])
      refute is_nil(access)

      # verify correct number of hierarchy elements were created
      containers = Oli.Publishing.get_unpublished_revisions_by_type(project.slug, "container")
      assert length(containers) == 38 + 1  # 38 defined in the course, plus 1 for the root

      # verify correct number of practice pages were created
      practice_pages = Oli.Publishing.get_unpublished_revisions_by_type(project.slug, "page")
      |> Enum.filter(fn p -> !p.graded end)
      assert length(practice_pages) == 49


      # spot check some elements to ensure that they were correctly constructed:

      # check an internal hierarchy node, one that contains references to only
      # other hierarchy nodes
      c = by_title(project, "Course Resources")
      assert length(c.children) == 2
      children = AuthoringResolver.from_resource_id(project.slug, c.children)
      assert Enum.at(children, 0).title == "Contents: Resources"
      assert Enum.at(children, 1).title == "Sub Course Resources"

      # check a leaf hierarchy node, one that contains only page references
      c = by_title(project, "Images")
      assert length(c.children) == 5
      children = AuthoringResolver.from_resource_id(project.slug, c.children)
      assert Enum.at(children, 0).title == "Digital Images"
      assert Enum.at(children, 1).title == "Image Code"
      assert Enum.at(children, 2).title == "Image Loop"
      assert Enum.at(children, 3).title == "Image Expressions"
      assert Enum.at(children, 4).title == "Image Puzzles"

      # check another leaf node, one with only a single page in it
      c = by_title(project, "Module with one page")
      assert length(c.children) == 1

    end

  end

end
