defmodule Oli.ScopedFeatureFlags.ScopedFeatureFlagStateTest do
  use Oli.DataCase
  import Ecto.Changeset, only: [get_field: 2]

  alias Oli.ScopedFeatureFlags.ScopedFeatureFlagState

  import Oli.Factory

  describe "changeset/2" do
    test "valid changeset with project_id using changeset_with_project/3" do
      project = insert(:project)

      changeset =
        ScopedFeatureFlagState.changeset_with_project(
          %ScopedFeatureFlagState{},
          %{feature_name: "mcp_authoring"},
          project.id
        )

      assert changeset.valid?
      assert get_field(changeset, :project_id) == project.id
    end

    test "valid changeset with section_id using changeset_with_section/3" do
      section = insert(:section)

      changeset =
        ScopedFeatureFlagState.changeset_with_section(
          %ScopedFeatureFlagState{},
          %{feature_name: "mcp_authoring"},
          section.id
        )

      assert changeset.valid?
      assert get_field(changeset, :section_id) == section.id
    end

    test "invalid changeset without feature_name" do
      project = insert(:project)

      changeset =
        ScopedFeatureFlagState.changeset_with_project(
          %ScopedFeatureFlagState{},
          %{},
          project.id
        )

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).feature_name
    end

    test "invalid changeset with empty feature_name" do
      project = insert(:project)

      changeset =
        ScopedFeatureFlagState.changeset_with_project(
          %ScopedFeatureFlagState{},
          %{feature_name: ""},
          project.id
        )

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).feature_name
    end

    test "invalid changeset with feature_name too long" do
      project = insert(:project)

      changeset =
        ScopedFeatureFlagState.changeset_with_project(
          %ScopedFeatureFlagState{},
          %{feature_name: String.duplicate("a", 256)},
          project.id
        )

      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).feature_name
    end

    test "invalid changeset with neither project_id nor section_id" do
      changeset =
        ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
          feature_name: "mcp_authoring"
        })

      refute changeset.valid?
      assert "Must specify either project_id or section_id" in errors_on(changeset).base
    end

    test "valid changeset with feature_name containing special characters" do
      project = insert(:project)

      changeset =
        ScopedFeatureFlagState.changeset_with_project(
          %ScopedFeatureFlagState{},
          %{feature_name: "feature_with-special.chars_123"},
          project.id
        )

      assert changeset.valid?
    end

    test "valid changeset with unicode feature_name" do
      project = insert(:project)

      changeset =
        ScopedFeatureFlagState.changeset_with_project(
          %ScopedFeatureFlagState{},
          %{feature_name: "功能_测试"},
          project.id
        )

      assert changeset.valid?
    end
  end

  describe "database constraints" do
    test "unique constraint on feature_name and project_id" do
      project = insert(:project)

      {:ok, _first} =
        ScopedFeatureFlagState.changeset_with_project(
          %ScopedFeatureFlagState{},
          %{feature_name: "mcp_authoring"},
          project.id
        )
        |> Repo.insert()

      assert {:error, changeset} =
               ScopedFeatureFlagState.changeset_with_project(
                 %ScopedFeatureFlagState{},
                 %{feature_name: "mcp_authoring"},
                 project.id
               )
               |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).feature_name
    end

    test "unique constraint on feature_name and section_id" do
      section = insert(:section)

      {:ok, _first} =
        ScopedFeatureFlagState.changeset_with_section(
          %ScopedFeatureFlagState{},
          %{feature_name: "mcp_authoring"},
          section.id
        )
        |> Repo.insert()

      assert {:error, changeset} =
               ScopedFeatureFlagState.changeset_with_section(
                 %ScopedFeatureFlagState{},
                 %{feature_name: "mcp_authoring"},
                 section.id
               )
               |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).feature_name
    end

    test "allows same feature_name for different projects" do
      project1 = insert(:project)
      project2 = insert(:project)

      {:ok, _first} =
        ScopedFeatureFlagState.changeset_with_project(
          %ScopedFeatureFlagState{},
          %{feature_name: "mcp_authoring"},
          project1.id
        )
        |> Repo.insert()

      assert {:ok, _second} =
               ScopedFeatureFlagState.changeset_with_project(
                 %ScopedFeatureFlagState{},
                 %{feature_name: "mcp_authoring"},
                 project2.id
               )
               |> Repo.insert()
    end

    test "allows same feature_name for different sections" do
      section1 = insert(:section)
      section2 = insert(:section)

      {:ok, _first} =
        ScopedFeatureFlagState.changeset_with_section(
          %ScopedFeatureFlagState{},
          %{feature_name: "mcp_authoring"},
          section1.id
        )
        |> Repo.insert()

      assert {:ok, _second} =
               ScopedFeatureFlagState.changeset_with_section(
                 %ScopedFeatureFlagState{},
                 %{feature_name: "mcp_authoring"},
                 section2.id
               )
               |> Repo.insert()
    end

    test "allows same feature_name for project and section (different resources)" do
      project = insert(:project)
      section = insert(:section)

      {:ok, _first} =
        ScopedFeatureFlagState.changeset_with_project(
          %ScopedFeatureFlagState{},
          %{feature_name: "mcp_authoring"},
          project.id
        )
        |> Repo.insert()

      assert {:ok, _second} =
               ScopedFeatureFlagState.changeset_with_section(
                 %ScopedFeatureFlagState{},
                 %{feature_name: "mcp_authoring"},
                 section.id
               )
               |> Repo.insert()
    end
  end

  describe "factory integration" do
    test "scoped_feature_flag_state factory creates valid record" do
      flag_state = insert(:scoped_feature_flag_state)
      assert flag_state.feature_name == "mcp_authoring"
      assert flag_state.project_id
      refute flag_state.section_id
    end

    test "scoped_feature_flag_state_for_project factory creates valid record" do
      flag_state = insert(:scoped_feature_flag_state_for_project)
      assert flag_state.feature_name == "mcp_authoring"
      assert flag_state.project_id
      refute flag_state.section_id
    end

    test "scoped_feature_flag_state_for_section factory creates valid record" do
      flag_state = insert(:scoped_feature_flag_state_for_section)
      assert flag_state.feature_name == "mcp_authoring"
      assert flag_state.section_id
      refute flag_state.project_id
    end
  end
end
