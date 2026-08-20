defmodule Oli.Interop.IngestTest do
  alias Oli.Interop.Ingest
  alias Oli.Interop.Export
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.Revision
  alias Oli.Repo
  alias Oli.Authoring.Editing.ObjectiveEditor
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
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

  describe "learning-model archive compatibility" do
    setup do
      Oli.Seeder.base_project_with_resource2()
    end

    test "legacy missing and null selections use documented fallbacks", %{author: author} do
      {:ok, legacy_project} =
        minimal_digest(%{"title" => "Legacy missing model"}, [
          %{"id" => "_product-legacy", "type" => "Product", "title" => "Legacy Product"}
        ])
        |> Ingest.process(author)

      assert legacy_project.learning_model_version == :naive

      legacy_product =
        Repo.get_by!(Section, base_project_id: legacy_project.id, type: :blueprint)

      assert legacy_product.learning_model_version == :naive

      {:ok, inherited_project} =
        minimal_digest(
          %{
            "title" => "Legacy Product inherits",
            "learningModelVersion" => "lkt_aoa"
          },
          [
            %{"id" => "_product-inherit", "type" => "Product", "title" => "Inherited Product"}
          ]
        )
        |> Ingest.process(author)

      assert inherited_project.learning_model_version == :lkt_aoa

      inherited_product =
        Repo.get_by!(Section, base_project_id: inherited_project.id, type: :blueprint)

      assert inherited_product.learning_model_version == :lkt_aoa

      {:ok, null_project} =
        minimal_digest(
          %{
            "title" => "Null models",
            "learningModelVersion" => nil
          },
          [
            %{
              "id" => "_product-null",
              "type" => "Product",
              "title" => "Null Product",
              "learningModelVersion" => nil
            }
          ]
        )
        |> Ingest.process(author)

      assert null_project.learning_model_version == :naive

      assert Repo.get_by!(Section, base_project_id: null_project.id).learning_model_version ==
               :naive

      {:ok, null_product_project} =
        minimal_digest(
          %{
            "title" => "Null Product inherits LKT-AOA",
            "learningModelVersion" => "lkt_aoa"
          },
          [
            %{
              "id" => "_product-null-inherits",
              "type" => "Product",
              "title" => "Null Product inherits",
              "learningModelVersion" => nil
            }
          ]
        )
        |> Ingest.process(author)

      assert null_product_project.learning_model_version == :lkt_aoa

      assert Repo.get_by!(Section, base_project_id: null_product_project.id).learning_model_version ==
               :lkt_aoa
    end

    test "invalid explicit Project and Product selections roll back with file context", %{
      author: author
    } do
      invalid_archives = [
        {minimal_digest(%{
           "title" => "Invalid project model",
           "learningModelVersion" => "v2"
         }), "_project.json"},
        {minimal_digest(%{"title" => "Invalid product model"}, [
           %{
             "id" => "misleading-internal-id",
             "archiveFile" => "_product-invalid",
             "type" => "Product",
             "title" => "Invalid Product",
             "learningModelVersion" => %{"unexpected" => true}
           }
         ]), "_product-invalid.json"}
      ]

      Enum.each(invalid_archives, fn {digest, expected_file} ->
        before_count = Repo.aggregate(Project, :count)

        assert {:error, error} = Ingest.process(digest, author)
        assert error =~ "Invalid learningModelVersion"
        assert error =~ expected_file
        assert Repo.aggregate(Project, :count) == before_count
      end)
    end

    test "imports learning parameters separately from generic objective parameters", %{
      author: author
    } do
      objective = %{
        "id" => "objective-parameters",
        "type" => "Objective",
        "title" => "Imported Parameterized Objective",
        "objectives" => [],
        "parameters" => %{"legacy" => "preserved"},
        "learningModelParameters" => learning_objective_envelope(0.0)
      }

      activity = %{
        "id" => "activity-untrained",
        "type" => "Activity",
        "title" => "Imported Untrained Activity",
        "subType" => "oli_multiple_choice",
        "objectives" => %{},
        "content" => activity_content(["part-1"])
      }

      assert {:ok, project} =
               minimal_digest(%{"title" => "Parameter separation"}, [], [objective, activity])
               |> Ingest.process(author)

      [imported_objective] =
        Oli.Publishing.get_unpublished_revisions_by_type(project.slug, "objective")
        |> Enum.filter(&(&1.title == "Imported Parameterized Objective"))

      [imported_activity] =
        Oli.Publishing.get_unpublished_revisions_by_type(project.slug, "activity")
        |> Enum.filter(&(&1.title == "Imported Untrained Activity"))

      assert imported_objective.parameters == %{"legacy" => "preserved"}
      assert imported_objective.learning_model_parameters.payload.beta_lo == 0.0
      assert imported_activity.learning_model_parameters == nil
    end

    test "invalid parameter envelopes roll back with resource context", %{author: author} do
      cases = [
        {"unsupported schema version",
         %{
           "id" => "misleading-objective-id",
           "archiveFile" => "objective-version",
           "type" => "Objective",
           "title" => "Bad Version",
           "objectives" => [],
           "learningModelParameters" =>
             Map.put(learning_objective_envelope(0.1), "schema_version", 99)
         }, "objective-version.json"},
        {"resource type mismatch",
         %{
           "id" => "objective-mismatch",
           "type" => "Objective",
           "title" => "Bad Type",
           "objectives" => [],
           "learningModelParameters" => activity_envelope(%{"part-1" => 0.2})
         }, "objective-mismatch.json"},
        {"reverse resource type mismatch",
         %{
           "id" => "activity-mismatch",
           "type" => "Activity",
           "title" => "Bad Activity Type",
           "subType" => "oli_multiple_choice",
           "objectives" => %{},
           "content" => activity_content(["part-1"]),
           "learningModelParameters" => learning_objective_envelope(0.2)
         }, "activity-mismatch.json"},
        {"unsupported model version",
         %{
           "id" => "objective-model-version",
           "type" => "Objective",
           "title" => "Bad Model Version",
           "objectives" => [],
           "learningModelParameters" =>
             Map.put(learning_objective_envelope(0.1), "model_version", 99)
         }, "objective-model-version.json"},
        {"unsupported parameter type",
         %{
           "id" => "objective-parameter-type",
           "type" => "Objective",
           "title" => "Bad Parameter Type",
           "objectives" => [],
           "learningModelParameters" =>
             Map.put(learning_objective_envelope(0.1), "parameter_type", "future_model")
         }, "objective-parameter-type.json"},
        {"non-finite coefficient",
         %{
           "id" => "objective-number",
           "type" => "Objective",
           "title" => "Bad Number",
           "objectives" => [],
           "learningModelParameters" => learning_objective_envelope("NaN")
         }, "objective-number.json"},
        {"unknown activity part",
         %{
           "id" => "activity-part",
           "type" => "Activity",
           "title" => "Bad Part",
           "subType" => "oli_multiple_choice",
           "objectives" => %{},
           "content" => activity_content(["known-part"]),
           "learningModelParameters" => activity_envelope(%{"unknown-part" => 0.2})
         }, "activity-part.json"}
      ]

      Enum.each(cases, fn {label, resource, expected_file} ->
        before_count = Repo.aggregate(Project, :count)

        assert {:error, error} =
                 minimal_digest(%{"title" => "Invalid #{label}"}, [], [resource])
                 |> Ingest.process(author)

        assert error =~ expected_file
        assert error =~ "learningModelParameters"
        assert Repo.aggregate(Project, :count) == before_count
      end)
    end
  end

  defp minimal_digest(project, products \\ [], resources \\ []) do
    base = [
      {~c"_project.json", Map.put_new(project, "description", "")},
      {~c"_hierarchy.json", %{"children" => []}},
      {~c"_media-manifest.json", %{"mediaItems" => []}}
    ]

    product_entries =
      Enum.map(products, fn product ->
        archive_file = Map.get(product, "archiveFile", product["id"])
        {String.to_charlist("#{archive_file}.json"), Map.delete(product, "archiveFile")}
      end)

    resource_entries =
      Enum.map(resources, fn resource ->
        archive_file = Map.get(resource, "archiveFile", resource["id"])
        {String.to_charlist("#{archive_file}.json"), Map.delete(resource, "archiveFile")}
      end)

    Enum.map(base ++ product_entries ++ resource_entries, fn {file, value} ->
      {file, Jason.encode!(value)}
    end)
  end

  defp learning_objective_envelope(beta_lo) do
    %{
      "schema_version" => 1,
      "model" => "lkt_aoa",
      "model_version" => 2,
      "parameter_type" => "learning_objective",
      "payload" => %{"beta_lo" => beta_lo}
    }
  end

  defp activity_envelope(parts) do
    %{
      "schema_version" => 1,
      "model" => "lkt_aoa",
      "model_version" => 2,
      "parameter_type" => "activity",
      "payload" => %{
        "parts" =>
          Map.new(parts, fn {part_id, beta_difficulty} ->
            {part_id, %{"beta_difficulty" => beta_difficulty}}
          end)
      }
    }
  end

  defp activity_content(part_ids) do
    %{"authoring" => %{"parts" => Enum.map(part_ids, &%{"id" => &1})}}
  end
end
