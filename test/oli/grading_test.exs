defmodule Oli.GradingTest do
  use Oli.DataCase

  alias Oli.Grading

  describe "grading" do
    defp populate_resource_accesses(map) do

    end

    setup do
      Oli.Seeder.base_project_with_resource2()
      |> Oli.Seeder.create_section
    end

    test "returns valid gradebook for section", %{section: section} do
      {gradebook, columns} = Grading.generate_gradebook_for_section(section)
    end
  end

end
