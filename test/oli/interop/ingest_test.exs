defmodule Oli.Interop.IngestTest do
  alias Oli.Interop.Ingest
  alias Oli.Interop.Export
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.Revision
  alias Oli.Repo
  alias Oli.Authoring.Editing.ObjectiveEditor
  use Oli.DataCase

  def by_title(project, title) do
    query =
      from r in Revision,
        where: r.title == ^title,
        limit: 1

    AuthoringResolver.from_revision_slug(project.slug, Repo.one(query).slug)
  end

  def verify_export(entries) do
    m = Enum.reduce(entries, %{}, fn {f, c}, m -> Map.put(m, f, c) end)

    assert length(entries) == 32
    assert Map.has_key?(m, ~c"_hierarchy.json")
    assert Map.has_key?(m, ~c"_media-manifest.json")
    assert Map.has_key?(m, ~c"_project.json")

    hierarchy =
      Map.get(m, ~c"_hierarchy.json")
      |> Jason.decode!()

    assert length(Map.get(hierarchy, "children")) == 2
    unit = Map.get(hierarchy, "children") |> hd
    assert Map.get(unit, "title") == "Unit 1"
    assert length(Map.get(unit, "children")) == 7
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

      assert project.welcome_title == %{
               "children" => [
                 %{
                   "text" => "Explore Northern Spain's Culinary Delights!"
                 }
               ],
               "id" => "3261709550",
               "type" => "p"
             }

      assert project.encouraging_subtitle == "Unlock Your Potential. Start Learning Today!"
      assert p.title == project.title
      assert p.attributes == project.attributes
      assert p.customizations == project.customizations

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

      # verify that the objectives were created
      objectives = ObjectiveEditor.fetch_objective_mappings(project)
      assert length(objectives) == 7

      # we have 2 objectives that have children so we check that it's correct
      assert Enum.reduce(objectives, 0, fn obj, acc ->
               if length(obj.revision.children) > 0, do: acc + 1, else: acc
             end)
             |> Kernel.===(2)

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

      citation =
        Enum.at(page_with_citation.content["model"], 0)
        |> Map.get("children")
        |> Enum.at(0)
        |> Map.get("children")
        |> Enum.at(1)

      bib_entries =
        Oli.Publishing.get_unpublished_revisions(project, [Map.get(citation, "bibref")])

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
      assert String.ends_with?(link["href"], dest.slug)

      # spot check some elements to ensure that they were correctly constructed:

      # check an internal hierarchy node, one that contains references to only
      # other hierarchy nodes
      c = by_title(project, "Unit 1")
      assert length(c.children) == 7
      children = AuthoringResolver.from_resource_id(project.slug, c.children)
      assert Enum.at(children, 0).title == "Introduction"
      assert Enum.at(children, 1).title == "Food and Drink of Galicia"
      assert Enum.at(children, 2).title == "Quiz 1"
      assert Enum.at(children, 2).max_attempts == 4
      assert Enum.at(children, 2).assessment_mode == :one_at_a_time
      assert Enum.at(children, 3).title == "Cuisine of Asturias"
      assert Enum.at(children, 5).title == "Final Quiz"

      # verify that all the activities were created correctly
      activities = Oli.Publishing.get_unpublished_revisions_by_type(project.slug, "activity")
      assert length(activities) == 10

      # verify the one activity that had a tag had the tag applied properly
      tag = Enum.filter(tags, fn p -> p.title == "Easy" end) |> hd

      tagged_activity =
        Enum.filter(activities, fn p -> p.title == "MCQ Sidre Pour Height" end) |> hd

      assert tagged_activity.tags == [tag.resource_id]

      # verify that the product was created
      product =
        Oli.Repo.get_by!(Oli.Delivery.Sections.Section, base_project_id: project.id)
        |> Repo.preload(:certificate)

      refute is_nil(product)
      assert product.type == :blueprint
      assert product.title == "This is a product"
      assert product.payment_options == :direct_and_deferred
      assert product.certificate.title == "Product 2"

      product_root =
        Oli.Repo.get!(Oli.Delivery.Sections.SectionResource, product.root_section_resource_id)

      assert Enum.count(product_root.children) == 2
    end
  end
end
