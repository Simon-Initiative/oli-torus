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

  # This mimics the result of unzipping a digest file, but instead reads the individual
  # files from disk (which makes updating and evolving this unit test easier). To mimic
  # the zip read result, we have to read all the JSON files in and present them as a
  # list of tuples where the first tuple item is a charlist representation of the file name
  # (just the file name, not the full path) and the second tuple item is the contents of
  # the file.
  def simulate_unzipping() do
    Path.wildcard("./test/oli/authoring/digest/*.json")
    |> Enum.map(fn f -> {String.split(f, "/") |> Enum.reverse |> hd |> String.to_charlist, File.read(f)} end)
    |> Enum.map(fn {f, {:ok, contents}} -> {f, contents} end)
  end

  describe "course project ingest" do

    setup do
      Oli.Seeder.base_project_with_resource2()
    end

    test "ingest/1 processes the digest files and creates a course", %{author: author} do

      {:ok, p} = simulate_unzipping()
      |> Ingest.process(author)

      # verify project
      project = Repo.get(Oli.Authoring.Course.Project, p.id)
      assert project.title == "KTH CS101"
      assert p.title == project.title

      # verify project access for author
      access = Repo.get_by(Oli.Authoring.Authors.AuthorProject, [author_id: author.id, project_id: project.id])
      refute is_nil(access)

      # verify correct number of hierarchy elements were created
      containers = Oli.Publishing.get_unpublished_revisions_by_type(project.slug, "container")
      assert length(containers) == 4 + 1  # 4 defined in the course, plus 1 for the root

      # verify correct number of practice pages were created
      practice_pages = Oli.Publishing.get_unpublished_revisions_by_type(project.slug, "page")
      |> Enum.filter(fn p -> !p.graded end)
      assert length(practice_pages) == 3

      # verify that every practice page has a content attribute with a model
      assert Enum.all?(practice_pages, fn p -> Map.has_key?(p.content, "model") end)


      # spot check some elements to ensure that they were correctly constructed:

      # check an internal hierarchy node, one that contains references to only
      # other hierarchy nodes
      c = by_title(project, "Analog and Digital Unit")
      assert length(c.children) == 3
      children = AuthoringResolver.from_resource_id(project.slug, c.children)
      assert Enum.at(children, 0).title == "Contents: Analog and Digital"
      assert Enum.at(children, 1).title == "Analog and Digital"
      assert Enum.at(children, 2).title == "Analog and Digital Quiz"

      # check a leaf hierarchy node, one that contains only page references
      c = by_title(project, "Analog and Digital")
      assert length(c.children) == 1
      children = AuthoringResolver.from_resource_id(project.slug, c.children)
      assert Enum.at(children, 0).title == "Analog and Digital Page"


      # verify that all the activities were created correctly
      activities = Oli.Publishing.get_unpublished_revisions_by_type(project.slug, "activity")
      assert length(activities) == 3



    end

  end

end
