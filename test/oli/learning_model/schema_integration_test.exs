defmodule Oli.LearningModel.SchemaIntegrationTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.LearningModel.Parameters
  alias Oli.LearningModel.V2.{ActivityParameters, LearningObjectiveParameters, PartParameters}
  alias Oli.Resources.{ResourceType, Revision}

  describe "learning model version schemas" do
    test "Project and Section use the semantic values and remain independent of analytics_version" do
      assert Ecto.Enum.values(Project, :learning_model_version) == [:naive, :lkt_aoa]
      assert Ecto.Enum.values(Section, :learning_model_version) == [:naive, :lkt_aoa]

      project_changeset =
        Project.trusted_learning_model_changeset(%Project{}, %{
          learning_model_version: :lkt_aoa,
          analytics_version: :v1
        })

      section_changeset =
        Section.trusted_learning_model_changeset(%Section{}, %{
          learning_model_version: :lkt_aoa,
          analytics_version: :v2
        })

      assert get_change(project_changeset, :learning_model_version) == :lkt_aoa
      assert get_change(section_changeset, :learning_model_version) == :lkt_aoa

      refute Project.trusted_learning_model_changeset(%Project{}, %{
               learning_model_version: :v3
             }).valid?

      refute Section.trusted_learning_model_changeset(%Section{}, %{
               learning_model_version: :v3
             }).valid?
    end

    test "ordinary changesets cannot mass-assign learning model selection" do
      project_changeset =
        Project.changeset(%Project{}, %{
          learning_model_version: :lkt_aoa,
          analytics_version: :v1
        })

      section_changeset =
        Section.changeset(%Section{}, %{
          learning_model_version: :lkt_aoa,
          analytics_version: :v1
        })

      refute Map.has_key?(project_changeset.changes, :learning_model_version)
      refute Map.has_key?(section_changeset.changes, :learning_model_version)
      assert get_change(project_changeset, :analytics_version) == :v1
      assert get_change(section_changeset, :analytics_version) == :v1
    end

    test "Ecto and ordinary Project creation defaults remain naive" do
      assert %Project{}.learning_model_version == :naive
      assert %Section{}.learning_model_version == :naive

      author = insert(:author)
      assert {:ok, %{project: project}} = Course.create_project("Naive project", author)
      assert project.learning_model_version == :naive
    end
  end

  describe "database migration contract" do
    test "selection columns are non-null with naive defaults and constrained values" do
      for table <- ["projects", "sections"] do
        %{rows: [[default, "NO"]]} =
          Ecto.Adapters.SQL.query!(
            Repo,
            """
            SELECT column_default, is_nullable
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = $1
              AND column_name = 'learning_model_version'
            """,
            [table]
          )

        assert default =~ "naive"

        %{rows: [[definition]]} =
          Ecto.Adapters.SQL.query!(
            Repo,
            """
            SELECT pg_get_constraintdef(oid)
            FROM pg_constraint
            WHERE conname = $1
            """,
            ["#{table}_learning_model_version_check"]
          )

        assert definition =~ "naive"
        assert definition =~ "lkt_aoa"

        %{rows: [[0]]} =
          Ecto.Adapters.SQL.query!(
            Repo,
            "SELECT count(*) FROM #{table} WHERE learning_model_version IS NULL",
            []
          )
      end
    end

    test "database constraints reject unsupported raw Project values" do
      project = insert(:project)

      assert_raise Postgrex.Error, ~r/projects_learning_model_version_check/, fn ->
        Ecto.Adapters.SQL.query!(
          Repo,
          "UPDATE projects SET learning_model_version = 'unsupported' WHERE id = $1",
          [project.id]
        )
      end
    end

    test "database constraints reject unsupported raw Section values" do
      section = insert(:section)

      assert_raise Postgrex.Error, ~r/sections_learning_model_version_check/, fn ->
        Ecto.Adapters.SQL.query!(
          Repo,
          "UPDATE sections SET learning_model_version = 'unsupported' WHERE id = $1",
          [section.id]
        )
      end
    end

    test "Revision parameter storage is nullable JSONB without a default or index" do
      assert %{rows: [["jsonb", "YES", nil]]} =
               Ecto.Adapters.SQL.query!(
                 Repo,
                 """
                 SELECT data_type, is_nullable, column_default
                 FROM information_schema.columns
                 WHERE table_schema = 'public'
                   AND table_name = 'revisions'
                   AND column_name = 'learning_model_parameters'
                 """,
                 []
               )

      assert %{rows: []} =
               Ecto.Adapters.SQL.query!(
                 Repo,
                 """
                 SELECT indexname
                 FROM pg_indexes
                 WHERE schemaname = 'public'
                   AND tablename = 'revisions'
                   AND indexdef ILIKE '%learning_model_parameters%'
                 """,
                 []
               )
    end
  end

  describe "Revision learning model parameters" do
    test "persists and loads typed LO parameters while preserving explicit zero" do
      parameters = learning_objective_parameters(0.0)

      assert {:ok, revision} =
               insert_revision(ResourceType.id_for_objective(), %{}, parameters)

      assert %Parameters{
               parameter_type: :learning_objective,
               payload: %LearningObjectiveParameters{beta_lo: beta_lo}
             } = Repo.get!(Revision, revision.id).learning_model_parameters

      assert beta_lo == 0.0
    end

    test "persists and loads typed activity-part parameters" do
      parameters = activity_parameters(%{"part-1" => -0.18, "part-2" => 0.37})
      content = %{"authoring" => %{"parts" => [%{"id" => "part-1"}, %{"id" => "part-2"}]}}

      assert {:ok, revision} =
               insert_revision(ResourceType.id_for_activity(), content, parameters)

      assert %Parameters{
               parameter_type: :activity,
               payload: %ActivityParameters{parts: parts}
             } = Repo.get!(Revision, revision.id).learning_model_parameters

      assert parts["part-1"].beta_difficulty == -0.18
      assert parts["part-2"].beta_difficulty == 0.37
    end

    test "allows missing parameters" do
      assert {:ok, revision} = insert_revision(ResourceType.id_for_objective(), %{}, nil)
      assert is_nil(Repo.get!(Revision, revision.id).learning_model_parameters)
    end

    test "rejects parameter payloads that do not match the Revision resource type" do
      assert {:error, changeset} =
               insert_revision(
                 ResourceType.id_for_activity(),
                 %{"authoring" => %{"parts" => []}},
                 learning_objective_parameters(0.2)
               )

      assert %{learning_model_parameters: [message]} = errors_on(changeset)
      assert message =~ "does not match"
    end

    test "rejects activity parameters for parts absent from the same Revision" do
      assert {:error, changeset} =
               insert_revision(
                 ResourceType.id_for_activity(),
                 %{"authoring" => %{"parts" => [%{"id" => "part-1"}]}},
                 activity_parameters(%{"unknown-part" => 0.2})
               )

      assert %{learning_model_parameters: [message]} = errors_on(changeset)
      assert message =~ "unknown-part"
    end

    test "returns a controlled changeset error for unsupported envelopes" do
      invalid_parameters = %{
        "schema_version" => 99,
        "model" => "lkt_aoa",
        "model_version" => 2,
        "parameter_type" => "learning_objective",
        "payload" => %{"beta_lo" => 0.2}
      }

      assert {:error, changeset} =
               insert_revision(ResourceType.id_for_objective(), %{}, invalid_parameters)

      assert %{learning_model_parameters: ["is invalid"]} = errors_on(changeset)
    end
  end

  defp insert_revision(resource_type_id, content, parameters) do
    author = insert(:author)
    resource = insert(:resource)

    %Revision{}
    |> Revision.changeset(%{
      title: "Learning-model parameter Revision",
      deleted: false,
      author_id: author.id,
      resource_id: resource.id,
      resource_type_id: resource_type_id,
      content: content,
      learning_model_parameters: parameters
    })
    |> Repo.insert()
  end

  defp learning_objective_parameters(beta_lo) do
    %Parameters{
      schema_version: 1,
      model: :lkt_aoa,
      model_version: 2,
      parameter_type: :learning_objective,
      payload: %LearningObjectiveParameters{beta_lo: beta_lo}
    }
  end

  defp activity_parameters(parts) do
    %Parameters{
      schema_version: 1,
      model: :lkt_aoa,
      model_version: 2,
      parameter_type: :activity,
      payload: %ActivityParameters{
        parts:
          Map.new(parts, fn {part_id, beta_difficulty} ->
            {part_id, %PartParameters{beta_difficulty: beta_difficulty}}
          end)
      }
    }
  end
end
