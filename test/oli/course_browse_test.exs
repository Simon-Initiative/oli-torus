defmodule Oli.CourseBrowseTest do
  use Oli.DataCase

  alias Oli.Course
  alias Oli.Accounts.Author
  alias Oli.Accounts.SystemRole
  alias Oli.Authoring.Course
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}

  def make_projects(prefix, n, author) do
    65..(65 + (n - 1))
    |> Enum.map(fn value -> List.to_string([value]) end)
    |> Enum.map(fn value -> Course.create_project("#{prefix}-#{value}", author) end)
    |> Enum.map(fn {:ok, %{project: project}} -> project end)
  end

  def browse(author, offset, limit, field, direction, deleted, filter) do
    Course.browse_projects(
      author,
      %Paging{offset: offset, limit: limit},
      %Sorting{field: field, direction: direction},
      deleted,
      filter
    )
  end

  describe "course browse functionality" do
    setup do
      {:ok, admin} =
        Author.noauth_changeset(%Author{}, %{
          email: "example@test.com",
          name: "Full name",
          given_name: "First",
          family_name: "Last",
          provider: "foo",
          system_role_id: SystemRole.role_id().admin
        })
        |> Repo.insert()

      {:ok, author} =
        Author.noauth_changeset(%Author{}, %{
          email: "someone@test.com",
          name: "new name",
          given_name: "First",
          family_name: "Last",
          provider: "foo",
          system_role_id: SystemRole.role_id().author
        })
        |> Repo.insert()

      make_projects("admin", 10, admin)
      make_projects("author", 11, author)
      [project] = make_projects("deleted", 1, author)
      Course.update_project(project, %{status: :deleted})

      %{admin: admin, author: author}
    end

    test "browse", %{
      author: author,
      admin: admin
    } do
      projects = browse(author, 0, 10, :title, :asc, false, "")
      assert length(projects) == 10
      assert hd(projects).total_count == 11

      projects = browse(admin, 0, 3, :title, :asc, false, "")
      assert length(projects) == 3
      assert hd(projects).total_count == 21

      projects = browse(admin, 0, 3, :title, :asc, false, "admin-")
      assert length(projects) == 3
      assert hd(projects).total_count == 10

      projects = browse(admin, 0, 3, :title, :asc, false, "admin-")
      assert hd(projects).title == "admin-A"
      projects = browse(admin, 0, 3, :title, :desc, false, "admin-")
      assert hd(projects).title == "admin-J"

      projects = browse(admin, 0, 10, :title, :asc, true, "")
      assert length(projects) == 10
      assert hd(projects).total_count == 22
    end
  end
end
