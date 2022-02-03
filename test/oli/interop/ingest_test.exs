defmodule Oli.Interop.IngestTest do
  alias Oli.Interop.Ingest
  alias Oli.Interop.Export
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.Revision
  alias Oli.Repo
  use Oli.DataCase

  def by_title(project, title) do
    query =
      from r in Revision,
        where: r.title == ^title,
        limit: 1

    AuthoringResolver.from_revision_slug(project.slug, Repo.one(query).slug)
  end

  def unzip_to_memory(data) do
    File.write("export.zip", data)
    result = :zip.unzip(to_charlist("export.zip"), [:memory])
    File.rm!("export.zip")

    case result do
      {:ok, entries} -> entries
      _ -> []
    end
  end

  def verify_export(entries) do
    assert length(entries) == 11

    m = Enum.reduce(entries, %{}, fn {f, c}, m -> Map.put(m, f, c) end)

    assert Map.has_key?(m, '_hierarchy.json')
    assert Map.has_key?(m, '_media-manifest.json')
    assert Map.has_key?(m, '_project.json')

    hierarchy =
      Map.get(m, '_hierarchy.json')
      |> Jason.decode!()

    assert length(Map.get(hierarchy, "children")) == 1
    unit = Map.get(hierarchy, "children") |> hd
    assert Map.get(unit, "title") == "Analog and Digital Unit"
  end

  # This mimics the result of unzipping a digest file, but instead reads the individual
  # files from disk (which makes updating and evolving this unit test easier). To mimic
  # the zip read result, we have to read all the JSON files in and present them as a
  # list of tuples where the first tuple item is a charlist representation of the file name
  # (just the file name, not the full path) and the second tuple item is the contents of
  # the file.
  def simulate_unzipping() do
    Path.wildcard("./test/oli/interop/digest/*.json")
    |> Enum.map(fn f ->
      {String.split(f, "/") |> Enum.reverse() |> hd |> String.to_charlist(), File.read(f)}
    end)
    |> Enum.map(fn {f, {:ok, contents}} -> {f, contents} end)
  end

  describe "course project ingest" do
    setup do
      Oli.Seeder.base_project_with_resource2()
    end

    test "ingest/1 and then export/1 works end to end", %{author: author} do
      {:ok, project} =
        simulate_unzipping()
        |> Ingest.process(author)

      Export.export(project)
      |> unzip_to_memory()
      |> verify_export()
    end

    test "ingest/1 processes the digest files and creates a course", %{author: author} do
      {:ok, p} =
        simulate_unzipping()
        |> Ingest.process(author)

      # verify project
      project = Repo.get(Oli.Authoring.Course.Project, p.id)
      assert project.title == "KTH CS101"
      assert p.title == project.title

      # verify project access for author
      access =
        Repo.get_by(Oli.Authoring.Authors.AuthorProject,
          author_id: author.id,
          project_id: project.id
        )

      refute is_nil(access)

      # verify that the tags were created
      tags = Oli.Publishing.get_unpublished_revisions_by_type(project.slug, "tag")
      assert length(tags) == 2

      # verify correct number of hierarchy elements were created
      containers = Oli.Publishing.get_unpublished_revisions_by_type(project.slug, "container")
      # 4 defined in the course, plus 1 for the root
      assert length(containers) == 4 + 1

      # verify correct number of practice pages were created
      practice_pages =
        Oli.Publishing.get_unpublished_revisions_by_type(project.slug, "page")
        |> Enum.filter(fn p -> !p.graded end)

      assert length(practice_pages) == 3

      # verify that every practice page has a content attribute with a model
      assert Enum.all?(practice_pages, fn p -> Map.has_key?(p.content, "model") end)

      # verify that the page that had a link to another page had that link rewired correctly
      src = Enum.filter(practice_pages, fn p -> p.title == "Analog and Digital Page" end) |> hd

      dest =
        Enum.filter(practice_pages, fn p -> p.title == "Contents: Analog and Digital Page" end)
        |> hd

      link =
        Enum.at(src.content["model"], 0)
        |> Map.get("children")
        |> Enum.at(1)
        |> Map.get("children")
        |> Enum.at(5)

      assert link["href"] == "/course/link/#{dest.slug}"

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

      # verify the one activity that had a tag had the tag applied properly
      tag = Enum.filter(tags, fn p -> p.title == "Easy" end) |> hd
      tagged_activity = Enum.filter(activities, fn p -> p.title == "CATA" end) |> hd
      assert tagged_activity.tags == [tag.resource_id]
    end

    test "returns :invalid_digest error when digest is invalid", %{author: author} do
      assert [] |> Ingest.process(author) == {:error, :invalid_digest}

      assert [
               {'file1', "some content"},
               {'_media-manifest', "{}"},
               {'_hierarchy', "{}"}
             ]
             |> Ingest.process(author) == {:error, :invalid_digest}

      assert [
               {'_project', "{}"},
               {'file1', "some content"},
               {'_hierarchy', "{}"}
             ]
             |> Ingest.process(author) == {:error, :invalid_digest}

      assert [
               {'_project', "{}"},
               {'_media-manifest', "{}"},
               {'file1', "some content"}
             ]
             |> Ingest.process(author) == {:error, :invalid_digest}
    end

    test "returns :missing_project_title error when project title is missing", %{author: author} do
      assert simulate_unzipping()
             |> Enum.map(fn item ->
               case item do
                 {'_project.json', contents} ->
                   without_title =
                     Jason.decode!(contents)
                     |> Map.delete("title")
                     |> Jason.encode!()

                   {'_project.json', without_title}

                 _ ->
                   item
               end
             end)
             |> Ingest.process(author) == {:error, :missing_project_title}
    end

    test "returns :empty_project_title error when project title is empty", %{author: author} do
      assert simulate_unzipping()
             |> Enum.map(fn item ->
               case item do
                 {'_project.json', contents} ->
                   without_title =
                     Jason.decode!(contents)
                     |> Map.put("title", "")
                     |> Jason.encode!()

                   {'_project.json', without_title}

                 _ ->
                   item
               end
             end)
             |> Ingest.process(author) == {:error, :empty_project_title}
    end

    test "returns :invalid_idrefs error when invalid iderefs are found", %{author: author} do
      assert simulate_unzipping()
             |> Enum.map(fn item ->
               case item do
                 {'_hierarchy.json', contents} ->
                   with_invalid_idref =
                     Jason.decode!(contents)
                     |> update_in(
                       ["children", Access.at(2), "children", Access.at(0), "children"],
                       fn children ->
                         children ++
                           [
                             %{
                               "type" => "item",
                               "children" => [],
                               "idref" => "some-invalid-idref"
                             }
                           ]
                       end
                     )
                     |> Jason.encode!()

                   {'_hierarchy.json', with_invalid_idref}

                 _ ->
                   item
               end
             end)
             |> Ingest.process(author) == {:error, {:invalid_idrefs, ["some-invalid-idref"]}}
    end
  end
end
