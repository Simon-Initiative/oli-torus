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
    assert length(entries) == 29

    m = Enum.reduce(entries, %{}, fn {f, c}, m -> Map.put(m, f, c) end)

    assert Map.has_key?(m, '_hierarchy.json')
    assert Map.has_key?(m, '_media-manifest.json')
    assert Map.has_key?(m, '_project.json')

    hierarchy =
      Map.get(m, '_hierarchy.json')
      |> Jason.decode!()

    assert length(Map.get(hierarchy, "children")) == 1
    unit = Map.get(hierarchy, "children") |> hd
    assert Map.get(unit, "title") == "Unit 1"
    assert length(Map.get(unit, "children")) == 6
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

    test "ingest/1 processes the digest files and creates a course and a product", %{
      author: author
    } do
      {:ok, p} =
        simulate_unzipping()
        |> Ingest.process(author)

      # verify project
      project = Repo.get(Oli.Authoring.Course.Project, p.id)
      assert project.title == "The Cuisine of Northern Spain"
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
      # 2 defined in the course, plus 1 for the root
      assert length(containers) == 2 + 1

      # verify correct number of practice pages were created
      practice_pages =
        Oli.Publishing.get_unpublished_revisions_by_type(project.slug, "page")
        |> Enum.filter(fn p -> !p.graded end)

      assert length(practice_pages) == 6

      # verify that every practice page has a content attribute with a model
      assert Enum.all?(practice_pages, fn p -> Map.has_key?(p.content, "model") end)

      # verify that citations are rewired correctly
      page_with_citation = Enum.filter(practice_pages, fn p -> p.title == "Feedback" end) |> hd
      citation = Enum.at(page_with_citation.content["model"], 0)
        |> Map.get("children")
        |> Enum.at(0)
        |> Map.get("children")
        |> Enum.at(1)

      bib_entries = Oli.Publishing.get_unpublished_revisions(project, [Map.get(citation, "bibref")])

      assert length(bib_entries) == 1

      # verify that the page that had a link to another page had that link rewired correctly
      src = Enum.filter(practice_pages, fn p -> p.title == "Introduction" end) |> hd

      dest =
        Enum.filter(practice_pages, fn p -> p.title == "Food and Drink of Galicia" end)
        |> hd

      link =
        Enum.at(src.content["model"], 0)
        |> Map.get("children")
        |> Enum.at(6)
        |> Map.get("children")
        |> Enum.at(1)
        |> Map.get("children")
        |> Enum.at(0)
        |> Map.get("children")
        |> Enum.at(0)
        |> Map.get("children")
        |> Enum.at(1)

      assert link["type"] == "a"
      assert link["href"] == "/course/link/#{dest.slug}"
      assert link["target"] == "self"

      # spot check some elements to ensure that they were correctly constructed:

      # check an internal hierarchy node, one that contains references to only
      # other hierarchy nodes
      c = by_title(project, "Unit 1")
      assert length(c.children) == 6
      children = AuthoringResolver.from_resource_id(project.slug, c.children)
      assert Enum.at(children, 0).title == "Introduction"
      assert Enum.at(children, 1).title == "Food and Drink of Galicia"
      assert Enum.at(children, 2).title == "Cuisine of Asturias"
      assert Enum.at(children, 4).title == "Final Quiz"

      # verify that all the activities were created correctly
      activities = Oli.Publishing.get_unpublished_revisions_by_type(project.slug, "activity")
      assert length(activities) == 10

      # verify the one activity that had a tag had the tag applied properly
      tag = Enum.filter(tags, fn p -> p.title == "Easy" end) |> hd

      tagged_activity =
        Enum.filter(activities, fn p -> p.title == "MCQ Sidre Pour Height" end) |> hd

      assert tagged_activity.tags == [tag.resource_id]

      # verify that the product was created
      product = Oli.Repo.get_by!(Oli.Delivery.Sections.Section, base_project_id: project.id)
      refute is_nil(product)
      assert product.type == :blueprint
      assert product.title == "This is a product"

      product_root =
        Oli.Repo.get!(Oli.Delivery.Sections.SectionResource, product.root_section_resource_id)

      assert Enum.count(product_root.children) == 2
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
                       ["children", Access.at(0), "children"],
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

    test "returns :invalid_json error when json fails schema validation", %{author: author} do
      assert {:error,
              {
                :invalid_json,
                _schema,
                [
                  {"Expected exactly one of the schemata to match, but none of them did.", "#"}
                ],
                _json
              }} =
               simulate_unzipping()
               |> Enum.map(fn item ->
                 case item do
                   {'35.json', contents} ->
                     with_invalid_json =
                       Jason.decode!(contents)
                       |> update_in(
                         ["content", "model"],
                         fn model ->
                           model ++
                             [
                               %{
                                 "invalid-type" => "invalid",
                                 "missing-children-id-purpose" => nil,
                                 "invalid-idref" => "some-invalid-idref"
                               }
                             ]
                         end
                       )
                       |> Jason.encode!()

                     {'35.json', with_invalid_json}

                   _ ->
                     item
                 end
               end)
               |> Ingest.process(author)
    end
  end
end
