defmodule Oli.EditingTest do
  use Oli.DataCase

  alias Oli.Editing

  describe "editing" do

    setup do
      Seeder.base_project_with_resource()
    end

    test "edit/4 creates a new revision when no lock in place", %{author: author, revision: revision } do

      content = [%{ "type" => "p", children: [%{ "text" => "A paragraph."}] }]
      {:ok, updated_revision} = Editing.edit("slug", "some_title", author.id, %{ content: content })

      assert revision.id != updated_revision.id
    end

  end

end
