defmodule Oli.EditingTest do
  use Oli.DataCase

  alias Oli.Authoring.Resources
  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Publishing
  alias Oli.Accounts.Author
  alias Oli.Accounts.SystemRole
  alias Oli.Utils.Time
  alias Oli.Locks

  describe "editing" do

    setup do
      Seeder.base_project_with_resource()
    end

    test "edit/4 creates a new revision when no lock in place", %{author: author, revision: revision } do

      content = [%{ "type" => "p", children: [%{ "text" => "A paragraph."}] }]
      {:ok, updated_revision} = ResourceEditor.edit("title", "some_title", author.email, %{ content: content })

      assert revision.id != updated_revision.id
    end

    test "edit/4 can edit multiple parameters", %{author: author } do

      content = [%{ "type" => "p", children: [%{ "text" => "A paragraph."}] }]
      title = "a new title"

      {:ok, updated_revision} = ResourceEditor.edit("title", "some_title", author.email, %{ title: title, content: content })

      # read it back from the db and verify both edits were made
      from_db = Resources.get_resource_revision!(updated_revision.id)

      assert "a new title" == from_db.title
      assert length(from_db.content) == 1
    end

    test "edit/4 can handle string keys in the update map", %{author: author } do

      title = "a new title"

      {:ok, updated_revision} = ResourceEditor.edit("title", "some_title", author.email, %{ "title" => title })

      # read it back from the db and verify both edits were made
      from_db = Resources.get_resource_revision!(updated_revision.id)

      assert "a new title" == from_db.title
    end

    test "edit/4 reuses the same revision when the lock is in place", %{mapping: mapping, author: author, revision: revision } do

      # set the lock so that it is valid and held by the same user
      Publishing.update_resource_mapping(mapping, %{lock_updated_at: Time.now(), locked_by_id: author.id})

      content = [%{ "type" => "p", children: [%{ "text" => "A paragraph."}] }]
      {:ok, updated_revision} = ResourceEditor.edit("title", "some_title", author.email, %{ content: content })

      assert revision.id == updated_revision.id
    end

    test "edit/4 generates a new revision when a lock has expired", %{mapping: mapping, author: author, revision: revision } do

      # set the lock so that it is valid and held by the same user
      Publishing.update_resource_mapping(mapping, %{lock_updated_at: yesterday(), locked_by_id: author.id})

      content = [%{ "type" => "p", children: [%{ "text" => "A paragraph."}] }]
      {:ok, updated_revision} = ResourceEditor.edit("title", "some_title", author.email, %{ content: content })

      assert revision.id != updated_revision.id
    end

    test "edit/4 fails when the lock cannot be acquired or updated", %{author: author, publication: publication, resource: resource } do

      # set the lock so that it is valid and held by a different user
      {:ok, author2} = Author.changeset(%Author{}, %{email: "test2@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: SystemRole.role_id.author}) |> Repo.insert
      {:acquired} = Locks.acquire(publication.id, resource.id, author2.id)

      # now try to make the edit with the original user
      content = [%{ "type" => "p", children: [%{ "text" => "A paragraph."}] }]
      result = ResourceEditor.edit("title", "some_title", author.email, %{ content: content })

      id = author2.id
      assert {:error, {:lock_not_acquired, {^id, _}}} = result
    end

    test "edit/4 fails when the resource slug is invalid", %{author: author } do

      # try to make the edit on a resource that isn't found via a revision slug
      content = [%{ "type" => "p", children: [%{ "text" => "A paragraph."}] }]
      result = ResourceEditor.edit("title", "some_missing_slug", author.email, %{ content: content })

      assert {:error, {:not_found}} = result
    end

    test "edit/4 fails when the project slug is invalid", %{author: author } do

      # try to make the edit on a resource that isn't found via a revision slug
      content = [%{ "type" => "p", children: [%{ "text" => "A paragraph."}] }]
      result = ResourceEditor.edit("some_missing_slug", "some_title", author.email, %{ content: content })

      assert {:error, {:not_found}} = result
    end

    test "edit/4 fails when the author doesn't have permission to edit", %{} do

      # try to make the edit using an unauthorized author
      content = [%{ "type" => "p", children: [%{ "text" => "A paragraph."}] }]
      {:ok, author2} = Author.changeset(%Author{}, %{email: "test2@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: SystemRole.role_id.author}) |> Repo.insert

      result = ResourceEditor.edit("title", "some_title", author2.email, %{ content: content })

      assert {:error, {:not_authorized}} = result
    end

  end

end
