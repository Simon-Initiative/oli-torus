defmodule Oli.LearningModel.OperationalStorageTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Attempts.Core.PartAttempt
  alias Oli.LearningModel.{AttemptApplication, LearningState, PriorActivityPartEvidence}

  describe "schema field contracts" do
    test "learning state stores only compact per learner and objective model state" do
      assert LearningState.__schema__(:primary_key) == [
               :section_id,
               :user_id,
               :learning_objective_id
             ]

      assert LearningState.__schema__(:fields) == [
               :section_id,
               :user_id,
               :learning_objective_id,
               :attempt_count,
               :success_score,
               :failure_score,
               :recency_logit,
               :aoa,
               :unique_activity_part_count,
               :confidence,
               :inserted_at,
               :updated_at
             ]

      refute :id in LearningState.__schema__(:fields)
      refute :latest_p_correct in LearningState.__schema__(:fields)
      refute :parameter_version_id in LearningState.__schema__(:fields)
    end

    test "prior evidence is keyed by activity part and has no update timestamp" do
      assert PriorActivityPartEvidence.__schema__(:primary_key) == [
               :section_id,
               :user_id,
               :activity_id,
               :part_id
             ]

      assert PriorActivityPartEvidence.__schema__(:fields) == [
               :section_id,
               :user_id,
               :activity_id,
               :part_id,
               :inserted_at
             ]
    end

    test "attempt application has exactly the three idempotency fields" do
      assert AttemptApplication.__schema__(:primary_key) == [:part_attempt_id]

      assert AttemptApplication.__schema__(:fields) == [
               :part_attempt_id,
               :learning_model_version,
               :applied_at
             ]

      assert Ecto.Enum.values(AttemptApplication, :learning_model_version) == [:naive, :lkt_aoa]
    end
  end

  describe "database constraints and defaults" do
    test "learning state defaults are neutral and constrained by the composite key" do
      section = insert(:section)
      user = insert(:user)
      objective = insert(:resource)

      assert {:ok, state} =
               Repo.insert(%LearningState{
                 section_id: section.id,
                 user_id: user.id,
                 learning_objective_id: objective.id
               })

      assert state.attempt_count == 0
      assert state.success_score == 0.0
      assert state.failure_score == 0.0
      assert state.recency_logit == 0.0
      assert state.aoa == 0.0
      assert state.unique_activity_part_count == 0
      assert state.confidence == 0.0
    end

    test "learning state numeric checks reject invalid persisted values" do
      section = insert(:section)
      user = insert(:user)
      objective = insert(:resource)

      assert_raise Postgrex.Error, ~r/learning_states_attempt_count_non_negative/, fn ->
        Ecto.Adapters.SQL.query!(
          Repo,
          """
          INSERT INTO learning_states (
            section_id,
            user_id,
            learning_objective_id,
            attempt_count,
            inserted_at,
            updated_at
          )
          VALUES ($1, $2, $3, -1, NOW(), NOW())
          """,
          [section.id, user.id, objective.id]
        )
      end
    end

    test "prior evidence uniqueness is per section, user, activity, and part" do
      section = insert(:section)
      user = insert(:user)
      activity = insert(:resource)

      attrs = %{
        section_id: section.id,
        user_id: user.id,
        activity_id: activity.id,
        part_id: "part-1"
      }

      assert {:ok, evidence} = Repo.insert(struct(PriorActivityPartEvidence, attrs))

      assert evidence.inserted_at

      assert unique_indexes("prior_activity_part_evidence") == [
               "prior_activity_part_evidence_pkey"
             ]
    end

    test "attempt application claim cascades when the source PartAttempt is deleted" do
      part_attempt = insert(:part_attempt)

      assert {:ok, application} =
               Repo.insert(%AttemptApplication{
                 part_attempt_id: part_attempt.id,
                 learning_model_version: :lkt_aoa,
                 applied_at: DateTime.utc_now() |> DateTime.truncate(:second)
               })

      assert application.part_attempt_id == part_attempt.id

      Repo.delete!(part_attempt)

      refute Repo.get(PartAttempt, part_attempt.id)
      refute Repo.get(AttemptApplication, part_attempt.id)
    end
  end

  describe "database shape" do
    test "attempt application table has no generated id or standard timestamps" do
      assert %{rows: rows} =
               Ecto.Adapters.SQL.query!(
                 Repo,
                 """
                 SELECT column_name
                 FROM information_schema.columns
                 WHERE table_schema = 'public'
                   AND table_name = 'learning_model_attempt_applications'
                 ORDER BY ordinal_position
                 """,
                 []
               )

      assert List.flatten(rows) == ["part_attempt_id", "learning_model_version", "applied_at"]
    end

    test "composite primary keys are the only uniqueness indexes on natural-key tables" do
      assert primary_key_columns("learning_states") == [
               "section_id",
               "user_id",
               "learning_objective_id"
             ]

      assert primary_key_columns("prior_activity_part_evidence") == [
               "section_id",
               "user_id",
               "activity_id",
               "part_id"
             ]

      assert unique_indexes("learning_states") == ["learning_states_pkey"]

      assert unique_indexes("prior_activity_part_evidence") == [
               "prior_activity_part_evidence_pkey"
             ]
    end

    test "derived rows cascade from their owning section, user, resource, and part attempt" do
      assert foreign_key_delete_rules("learning_states") == %{
               "learning_objective_id" => "CASCADE",
               "section_id" => "CASCADE",
               "user_id" => "CASCADE"
             }

      assert foreign_key_delete_rules("prior_activity_part_evidence") == %{
               "activity_id" => "CASCADE",
               "section_id" => "CASCADE",
               "user_id" => "CASCADE"
             }

      assert foreign_key_delete_rules("learning_model_attempt_applications") == %{
               "part_attempt_id" => "CASCADE"
             }
    end
  end

  defp primary_key_columns(table) do
    %{rows: rows} =
      Ecto.Adapters.SQL.query!(
        Repo,
        """
        SELECT a.attname
        FROM pg_index i
        JOIN pg_attribute a
          ON a.attrelid = i.indrelid
         AND a.attnum = ANY(i.indkey)
        WHERE i.indrelid = $1::text::regclass
          AND i.indisprimary
        ORDER BY array_position(i.indkey, a.attnum)
        """,
        [table]
      )

    List.flatten(rows)
  end

  defp unique_indexes(table) do
    %{rows: rows} =
      Ecto.Adapters.SQL.query!(
        Repo,
        """
        SELECT indexname
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = $1
          AND indexdef ILIKE '%UNIQUE%'
        ORDER BY indexname
        """,
        [table]
      )

    List.flatten(rows)
  end

  defp foreign_key_delete_rules(table) do
    %{rows: rows} =
      Ecto.Adapters.SQL.query!(
        Repo,
        """
        SELECT kcu.column_name, rc.delete_rule
        FROM information_schema.referential_constraints rc
        JOIN information_schema.key_column_usage kcu
          ON kcu.constraint_catalog = rc.constraint_catalog
         AND kcu.constraint_schema = rc.constraint_schema
         AND kcu.constraint_name = rc.constraint_name
        WHERE rc.constraint_schema = 'public'
          AND kcu.table_name = $1
        ORDER BY kcu.column_name
        """,
        [table]
      )

    Map.new(rows, fn [column, delete_rule] -> {column, delete_rule} end)
  end
end
