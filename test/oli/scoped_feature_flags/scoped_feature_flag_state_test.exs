defmodule Oli.ScopedFeatureFlags.ScopedFeatureFlagStateTest do
  use Oli.DataCase

  alias Oli.ScopedFeatureFlags.ScopedFeatureFlagState

  import Oli.Factory

  describe "changeset/2" do
    test "valid changeset with project_id" do
      project = insert(:project)

      changeset =
        ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
          feature_name: "mcp_authoring",
          enabled: true,
          project_id: project.id
        })

      assert changeset.valid?
    end

    test "valid changeset with section_id" do
      section = insert(:section)

      changeset =
        ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
          feature_name: "mcp_authoring",
          enabled: false,
          section_id: section.id
        })

      assert changeset.valid?
    end

    test "invalid changeset without feature_name" do
      project = insert(:project)

      changeset =
        ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
          enabled: true,
          project_id: project.id
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).feature_name
    end

    test "invalid changeset without enabled field" do
      project = insert(:project)

      changeset =
        ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
          feature_name: "mcp_authoring",
          project_id: project.id
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).enabled
    end

    test "invalid changeset with empty feature_name" do
      project = insert(:project)

      changeset =
        ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
          feature_name: "",
          enabled: true,
          project_id: project.id
        })

      refute changeset.valid?
      assert "should be at least 1 character(s)" in errors_on(changeset).feature_name
    end

    test "invalid changeset with feature_name too long" do
      project = insert(:project)

      changeset =
        ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
          feature_name: String.duplicate("a", 256),
          enabled: true,
          project_id: project.id
        })

      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).feature_name
    end

    test "invalid changeset with both project_id and section_id" do
      project = insert(:project)
      section = insert(:section)

      changeset =
        ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
          feature_name: "mcp_authoring",
          enabled: true,
          project_id: project.id,
          section_id: section.id
        })

      refute changeset.valid?
      assert "Cannot specify both project_id and section_id" in errors_on(changeset).base
    end

    test "invalid changeset with neither project_id nor section_id" do
      changeset =
        ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
          feature_name: "mcp_authoring",
          enabled: true
        })

      refute changeset.valid?
      assert "Must specify either project_id or section_id" in errors_on(changeset).base
    end

    test "invalid changeset with non-existent project_id" do
      changeset =
        ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
          feature_name: "mcp_authoring",
          enabled: true,
          project_id: 999_999
        })

      assert changeset.valid?

      # Database constraint should be tested at the repo level
      assert {:error, changeset} =
               Repo.insert(changeset)

      assert "does not exist" in errors_on(changeset).project_id
    end

    test "invalid changeset with non-existent section_id" do
      changeset =
        ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
          feature_name: "mcp_authoring",
          enabled: true,
          section_id: 999_999
        })

      assert changeset.valid?

      # Database constraint should be tested at the repo level
      assert {:error, changeset} =
               Repo.insert(changeset)

      assert "does not exist" in errors_on(changeset).section_id
    end
  end

  describe "database constraints" do
    test "unique constraint on feature_name and project_id" do
      project = insert(:project)

      {:ok, _first} =
        ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
          feature_name: "mcp_authoring",
          enabled: true,
          project_id: project.id
        })
        |> Repo.insert()

      assert {:error, changeset} =
               ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
                 feature_name: "mcp_authoring",
                 enabled: false,
                 project_id: project.id
               })
               |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).feature_name
    end

    test "unique constraint on feature_name and section_id" do
      section = insert(:section)

      {:ok, _first} =
        ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
          feature_name: "mcp_authoring",
          enabled: true,
          section_id: section.id
        })
        |> Repo.insert()

      assert {:error, changeset} =
               ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
                 feature_name: "mcp_authoring",
                 enabled: false,
                 section_id: section.id
               })
               |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).feature_name
    end

    test "allows same feature_name for different projects" do
      project1 = insert(:project)
      project2 = insert(:project)

      {:ok, _first} =
        ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
          feature_name: "mcp_authoring",
          enabled: true,
          project_id: project1.id
        })
        |> Repo.insert()

      assert {:ok, _second} =
               ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
                 feature_name: "mcp_authoring",
                 enabled: false,
                 project_id: project2.id
               })
               |> Repo.insert()
    end

    test "allows same feature_name for different sections" do
      section1 = insert(:section)
      section2 = insert(:section)

      {:ok, _first} =
        ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
          feature_name: "mcp_authoring",
          enabled: true,
          section_id: section1.id
        })
        |> Repo.insert()

      assert {:ok, _second} =
               ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
                 feature_name: "mcp_authoring",
                 enabled: false,
                 section_id: section2.id
               })
               |> Repo.insert()
    end

    test "allows same feature_name for project and section (different resources)" do
      project = insert(:project)
      section = insert(:section)

      {:ok, _first} =
        ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
          feature_name: "mcp_authoring",
          enabled: true,
          project_id: project.id
        })
        |> Repo.insert()

      assert {:ok, _second} =
               ScopedFeatureFlagState.changeset(%ScopedFeatureFlagState{}, %{
                 feature_name: "mcp_authoring",
                 enabled: false,
                 section_id: section.id
               })
               |> Repo.insert()
    end
  end

  describe "factory integration" do
    test "scoped_feature_flag_state factory creates valid record" do
      flag_state = insert(:scoped_feature_flag_state)
      assert flag_state.feature_name == "mcp_authoring"
      assert flag_state.enabled == false
      assert flag_state.project_id
      refute flag_state.section_id
    end

    test "scoped_feature_flag_state_for_project factory creates valid record" do
      flag_state = insert(:scoped_feature_flag_state_for_project, enabled: true)
      assert flag_state.feature_name == "mcp_authoring"
      assert flag_state.enabled == true
      assert flag_state.project_id
      refute flag_state.section_id
    end

    test "scoped_feature_flag_state_for_section factory creates valid record" do
      flag_state = insert(:scoped_feature_flag_state_for_section, enabled: true)
      assert flag_state.feature_name == "mcp_authoring"
      assert flag_state.enabled == true
      assert flag_state.section_id
      refute flag_state.project_id
    end
  end
end
