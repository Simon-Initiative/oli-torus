defmodule Oli.ActivityEditingTest do
  use Oli.DataCase

  alias Oli.Editing.ActivityEditor

  describe "editing" do

    setup do
      Seeder.base_project_with_resource()
    end

    test "create/4 creates an activity revision", %{author: author, project: project } do

      content = %{ "stem" => "Hey there" }
      {:ok, revision} = ActivityEditor.create(project.slug, "oli_multiple_choice", author, content)
      assert revision.content == %{ "stem" => "Hey there" }
    end


  end

end
