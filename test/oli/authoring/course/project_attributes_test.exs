defmodule Oli.Authoring.Course.ProjectAttributesTest do
  use Oli.DataCase, async: true

  alias Ecto.Changeset
  alias Oli.Authoring.Course.ProjectAttributes

  test "uses recommended coverage thresholds by default" do
    assert %ProjectAttributes{coverage_formative_threshold: 3, coverage_summative_threshold: 3} =
             %ProjectAttributes{}
  end

  test "casts non-negative coverage thresholds" do
    attributes =
      %ProjectAttributes{}
      |> ProjectAttributes.changeset(%{
        coverage_formative_threshold: "4",
        coverage_summative_threshold: "2"
      })
      |> Changeset.apply_changes()

    assert attributes.coverage_formative_threshold == 4
    assert attributes.coverage_summative_threshold == 2
  end

  test "rejects negative coverage thresholds" do
    changeset =
      ProjectAttributes.changeset(%ProjectAttributes{}, %{
        coverage_formative_threshold: -1,
        coverage_summative_threshold: -1
      })

    assert %{coverage_formative_threshold: ["must be greater than or equal to 0"]} =
             errors_on(changeset)

    assert %{coverage_summative_threshold: ["must be greater than or equal to 0"]} =
             errors_on(changeset)
  end

  describe "coverage_thresholds/1" do
    test "reads the persisted thresholds" do
      attributes = %ProjectAttributes{
        coverage_formative_threshold: 5,
        coverage_summative_threshold: 2
      }

      assert ProjectAttributes.coverage_thresholds(attributes) == %{formative: 5, summative: 2}
    end

    test "defaults to 3/3 for a project with no attributes embed" do
      assert ProjectAttributes.coverage_thresholds(nil) == %{formative: 3, summative: 3}
    end
  end
end
