defmodule Oli.Resources.PageBrowseTest do
  use Oli.DataCase

  alias Oli.Course
  alias Oli.Accounts.Author
  alias Oli.Accounts.SystemRole
  alias Oli.Authoring.Course
  alias Oli.Resources.{PageBrowse, PageBrowseOptions}
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}

  def make_pages(project, publication, author, n) do
    65..(65 + (n - 1))
    |> Enum.map(fn value ->
      Course.create_and_attach_resource(project, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        title: List.to_string([value]),
        author_id: author.id,
        content:
          if rem(value, 4) == 0 do
            %{"advancedDelivery" => "true"}
          else
            %{}
          end,
        graded:
          if rem(value, 3) == 0 do
            true
          else
            false
          end
      })
    end)
    |> Enum.map(fn {:ok, %{revision: revision}} ->
      Oli.Publishing.create_published_resource(%{
        publication_id: publication.id,
        resource_id: revision.resource_id,
        revision_id: revision.id
      })

      revision
    end)
  end

  def browse(project, options \\ []) do
    PageBrowse.browse_pages(
      project,
      struct(Paging, options),
      struct(Sorting, options),
      struct(PageBrowseOptions, options)
    )
  end

  describe "page browse functionality" do
    setup do
      {:ok, author} =
        Author.noauth_changeset(%Author{}, %{
          email: "example@test.com",
          name: "Full name",
          given_name: "First",
          family_name: "Last",
          provider: "foo",
          system_role_id: SystemRole.role_id().admin
        })
        |> Repo.insert()

      {:ok, %{project: project, publication: publication}} = Course.create_project("test", author)
      pages = make_pages(project, publication, author, 20)

      %{project: project, pages: pages, author: author, publication: publication}
    end

    test "browse", %{
      project: project
    } do
      pages = browse(project, offset: 0, limit: 10, direction: :asc, field: :title)
      assert length(pages) == 10
      assert hd(pages).total_count == 20

      # Verify limit and offset
      pages = browse(project, offset: 0, limit: 5, direction: :asc, field: :title)
      assert length(pages) == 5
      assert hd(pages).total_count == 20
      pages = browse(project, offset: 19, limit: 5, direction: :asc, field: :title)
      assert length(pages) == 1
      assert hd(pages).total_count == 20

      # Verify sort by title
      pages = browse(project, offset: 0, limit: 5, direction: :desc, field: :title)
      assert hd(pages).title == "T"

      # Verify sorting by graded words
      pages = browse(project, offset: 0, limit: 5, direction: :asc, field: :graded)
      assert hd(pages).graded == false
      pages = browse(project, offset: 0, limit: 5, direction: :desc, field: :graded)
      assert hd(pages).graded == true

      # Verify sorting by the virtual page_type attr works
      pages = browse(project, offset: 0, limit: 5, direction: :asc, field: :page_type)
      assert hd(pages).page_type == "Advanced"
      pages = browse(project, offset: 0, limit: 5, direction: :desc, field: :page_type)
      assert hd(pages).page_type == "Regular"

      # Verify filter by deleted
      pages = browse(project, offset: 0, limit: 5, direction: :asc, field: :title, deleted: true)
      assert pages == []
      pages = browse(project, offset: 0, limit: 5, direction: :asc, field: :title, deleted: false)
      assert length(pages) == 5
      assert hd(pages).total_count == 20

      # Verify filter by graded
      pages = browse(project, offset: 0, limit: 5, direction: :asc, field: :title, graded: true)
      assert length(pages) == 5
      assert hd(pages).total_count == 7
      pages = browse(project, offset: 0, limit: 5, direction: :asc, field: :title, graded: false)
      assert length(pages) == 5
      assert hd(pages).total_count == 13

      # Verify filter by page_type
      pages = browse(project, offset: 0, limit: 5, direction: :asc, field: :title, basic: true)
      assert length(pages) == 5
      assert hd(pages).total_count == 15
      pages = browse(project, offset: 0, limit: 5, direction: :asc, field: :title, basic: false)
      assert length(pages) == 5
      assert hd(pages).total_count == 5

      # Verify filter by text_search
      pages =
        browse(project, offset: 0, limit: 5, direction: :asc, field: :title, text_search: "A")

      assert length(pages) == 1
      assert hd(pages).total_count == 1

      # Verify filter by page_type and by graded
      pages =
        browse(project,
          offset: 0,
          limit: 5,
          direction: :asc,
          field: :title,

          # only the "value" of 72 and 84 both were advanced delivery
          # and graded
          basic: false,
          graded: true
        )

      assert length(pages) == 2
      assert hd(pages).total_count == 2
    end

    test "find parent container", %{
      project: project,
      publication: publication,
      pages: [first | _rest]
    } do
      assert PageBrowse.find_parent_container(project, first) == []

      container =
        Oli.Publishing.AuthoringResolver.from_resource_id(
          project.slug,
          publication.root_resource_id
        )

      Oli.Publishing.ChangeTracker.track_revision(project.slug, container, %{
        children: [first.resource_id]
      })

      [
        %{resource_id: resource_id}
      ] = PageBrowse.find_parent_container(project, first)

      assert resource_id == container.resource_id
    end
  end
end
