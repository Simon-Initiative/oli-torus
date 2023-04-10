defmodule Oli.BibEntryEditorTest do
  use Oli.DataCase

  alias Oli.Resources.Revision
  alias Oli.Authoring.Editing.BibEntryEditor
  alias Oli.Accounts.{SystemRole, Author}
  alias Oli.Repo.{Paging}
  alias Oli.Repo

  describe "bib entry editing" do
    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.create_bib_entry(:first, "Correlation of the Base Strengths of Amines 1", %{data: Poison.decode!('[{
        "container-title": "Journal of the American Chemical Society",
        "author": [{
          "given": "H. K.",
          "family": "Hall"
        }],
        "type": "article-journal",
        "id": "Hall1957Correlation",
        "citation-label": "Hall1957Correlation",
        "issue": "20",
        "issued": {
          "date-parts": [
            [1957, 1, 1]
          ]
        },
        "page": "5441-5444",
        "title": "Correlation of the Base Strengths of Amines 1",
        "volume": "79"
      }]')})
      |> Seeder.create_bib_entry(:second, "Gitksan medicinal plants-cultural choice and efficacy", %{data: Poison.decode!('[{
        "container-title": "Journal of Ethnobiology and Ethnomedicine",
        "author": [{
          "given": "Leslie Main",
          "family": "Johnson"
        }],
        "type": "article-journal",
        "id": "Johnson2006Gitksan",
        "citation-label": "Johnson2006Gitksan",
        "issue": "1",
        "issued": {
          "date-parts": [
            [2006, 6, 21]
          ]
        },
        "publisher": "BioMed Central",
        "title": "Gitksan medicinal plants-cultural choice and efficacy",
        "volume": "2"
      }]')})
    end

    test "list/2 lists both bib_entrys", %{author: author, project: project, first: first, second: second} do
      {:ok, revisions} = BibEntryEditor.list(project.slug, author)

      assert length(revisions) == 2
      assert Enum.at(revisions, 0).resource_id == first.revision.resource_id
      assert Enum.at(revisions, 1).resource_id == second.revision.resource_id
    end

    test "browse_entrys/3 lists paged bib_entrys", %{author: author, project: project, first: first} do
      {:ok, revisions} = BibEntryEditor.retrieve(project.slug, author, %Paging{limit: 1, offset: 0})

      assert length(revisions.rows) == 1
      assert Enum.at(revisions.rows, 0).resource_id == first.revision.resource_id
    end

    test "list/2 fails when project does not exist", %{
      author: author
    } do
      assert {:error, {:not_found}} == BibEntryEditor.list("does_not_exist", author)
    end

    test "list/2 fails when author does not have access", %{
      project: project
    } do
      {:ok, author} =
        Author.noauth_changeset(%Author{}, %{
          email: "newone@test.com",
          given_name: "First",
          family_name: "Last",
          provider: "foo",
          system_role_id: SystemRole.role_id().author
        })
        |> Repo.insert()

      assert {:error, {:not_authorized}} == BibEntryEditor.list(project.slug, author)
    end

    test "edit/4 fails when project does not exist", %{
      author: author,
      first: first
    } do
      assert {:error, {:not_found}} ==
        BibEntryEditor.edit("does_not_exist", first.revision.resource_id, author, %{
                 "title" => "test"
               })
    end

    test "edit/4 fails when bib_entry resource id does not exist", %{
      author: author,
      project: project
    } do
      assert {:error, {:not_found}} ==
        BibEntryEditor.edit(project.slug, 22222, author, %{
                 "title" => "test"
               })
    end

    test "edit/4 fails when author does not have access", %{
      project: project,
      first: first
    } do
      {:ok, author} =
        Author.noauth_changeset(%Author{}, %{
          email: "newone@test.com",
          given_name: "First",
          family_name: "Last",
          provider: "foo",
          system_role_id: SystemRole.role_id().author
        })
        |> Repo.insert()

      assert {:error, {:not_authorized}} ==
        BibEntryEditor.edit(project.slug, first.revision.resource_id, author, %{
                 "title" => "test"
               })
    end

    test "edit/4 allows title editing", %{author: author, project: project, first: first} do
      {:ok, %Revision{} = _revision} =
        BibEntryEditor.edit(project.slug, first.revision.resource_id, author, %{
          "title" => "updated title"
        })

      revision =
        Oli.Publishing.AuthoringResolver.from_resource_id(project.slug, first.revision.resource_id)

      refute revision.id == first.revision.id
      assert revision.title == "updated title"

      {:ok, revisions} = BibEntryEditor.list(project.slug, author)
      assert length(revisions) == 2
      assert Enum.at(revisions, 0).resource_id == first.revision.resource_id
    end

    test "deleting a bib_entry makes it inaccessible via list/2", %{
      author: author,
      project: project,
      first: first,
      second: second
    } do
      {:ok, %Revision{} = _revision} =
        BibEntryEditor.edit(project.slug, first.revision.resource_id, author, %{
          "deleted" => true
        })

      revision =
        Oli.Publishing.AuthoringResolver.from_resource_id(project.slug, first.revision.resource_id)

      refute revision.id == first.revision.id
      assert revision.deleted == true

      {:ok, revisions} = BibEntryEditor.list(project.slug, author)
      assert length(revisions) == 1
      assert Enum.at(revisions, 0).resource_id == second.revision.resource_id
    end
  end
end
