defmodule Oli.Repo.Migrations.RepairInstructorEmailFeatureConfigDefaultTest do
  @moduledoc """
  Verifies the backfill logic of
  `20260630120000_repair_instructor_email_feature_config_default`.

  The two statements below mirror the migration's `up/0` verbatim. The migration
  keeps its SQL self-contained (safe-migration guidance: independent from app
  code), so the test re-runs the identical SQL against a sandboxed DB to exercise
  the real behavior: name-agnostic source, single-row determinism, and
  `WHERE NOT EXISTS` idempotency.
  """
  use Oli.DataCase

  import Ecto.Query

  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig}
  alias Oli.GenAI.FeatureConfig
  alias Oli.Repo

  @service_config_sql """
  INSERT INTO completions_service_configs
    (name, primary_model_id, backup_model_id, inserted_at, updated_at)
  SELECT 'instructor-email-default', src.model_id, NULL, NOW(), NOW()
  FROM (
    SELECT COALESCE(
      (SELECT sc.primary_model_id
         FROM gen_ai_feature_configs g
         JOIN completions_service_configs sc ON sc.id = g.service_config_id
        WHERE g.feature = 'student_dialogue' AND g.section_id IS NULL
        ORDER BY g.id
        LIMIT 1),
      (SELECT id FROM registered_models ORDER BY id LIMIT 1)
    ) AS model_id
  ) src
  WHERE src.model_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM completions_service_configs
       WHERE name = 'instructor-email-default'
    )
    AND NOT EXISTS (
      SELECT 1 FROM gen_ai_feature_configs
       WHERE feature = 'instructor_email' AND section_id IS NULL
    );
  """

  @feature_config_sql """
  INSERT INTO gen_ai_feature_configs
    (feature, service_config_id, section_id, inserted_at, updated_at)
  SELECT 'instructor_email', sc.id, NULL, NOW(), NOW()
  FROM completions_service_configs sc
  WHERE sc.name = 'instructor-email-default'
    AND NOT EXISTS (
      SELECT 1 FROM gen_ai_feature_configs
       WHERE feature = 'instructor_email' AND section_id IS NULL
    )
  ORDER BY sc.id
  LIMIT 1;
  """

  # The test DB is seeded with the full GenAI defaults (including an
  # instructor_email global). Wipe the three tables so each scenario below
  # exercises the backfill from a known, controlled state. The sandbox rolls
  # this back after every test.
  setup do
    Repo.delete_all(FeatureConfig)
    Repo.delete_all(ServiceConfig)
    Repo.delete_all(RegisteredModel)
    :ok
  end

  defp backfill! do
    Repo.query!(@service_config_sql)
    Repo.query!(@feature_config_sql)
  end

  defp insert_model(name) do
    Repo.insert!(%RegisteredModel{
      name: name,
      provider: :open_ai,
      model: "gpt-4",
      url_template: "https://api.example.com",
      api_key: "secret",
      timeout: 8000,
      recv_timeout: 60_000
    })
  end

  defp global_email_configs do
    Repo.all(
      from(g in FeatureConfig, where: g.feature == :instructor_email and is_nil(g.section_id))
    )
  end

  describe "Tokamaka shape: existing config named 'standard', no 'standard-no-backup'" do
    setup do
      model = insert_model("Primary Model")

      service_config =
        Repo.insert!(%ServiceConfig{name: "standard", primary_model_id: model.id})

      # The canonical GenAI default seeded on every environment.
      Repo.insert!(%FeatureConfig{
        feature: :student_dialogue,
        service_config_id: service_config.id,
        section_id: nil
      })

      %{model: model}
    end

    test "creates exactly one global instructor_email config from the student_dialogue default",
         %{model: model} do
      backfill!()

      email_service_config = Repo.get_by!(ServiceConfig, name: "instructor-email-default")
      assert email_service_config.primary_model_id == model.id
      assert is_nil(email_service_config.backup_model_id)

      assert [config] = global_email_configs()
      assert config.service_config_id == email_service_config.id
    end

    test "is idempotent across repeated runs" do
      backfill!()
      backfill!()
      backfill!()

      assert Repo.aggregate(
               from(s in ServiceConfig, where: s.name == "instructor-email-default"),
               :count
             ) == 1

      assert length(global_email_configs()) == 1
    end
  end

  describe "fallback when no student_dialogue default exists" do
    test "derives the model from the lowest-id registered model" do
      lowest = insert_model("Lowest")
      _higher = insert_model("Higher")

      backfill!()

      email_service_config = Repo.get_by!(ServiceConfig, name: "instructor-email-default")
      assert email_service_config.primary_model_id == lowest.id
      assert [_config] = global_email_configs()
    end

    test "creates nothing when there is no source model at all" do
      backfill!()

      assert Repo.aggregate(
               from(s in ServiceConfig, where: s.name == "instructor-email-default"),
               :count
             ) == 0

      assert global_email_configs() == []
    end
  end

  describe "a global instructor_email config already exists" do
    test "creates no orphan instructor-email-default service config" do
      model = insert_model("Primary Model")

      other_config =
        Repo.insert!(%ServiceConfig{name: "standard", primary_model_id: model.id})

      # Operator/console already provisioned the global config against another
      # service config (e.g. an earlier manual workaround). The backfill must
      # no-op entirely, not leave behind an unused instructor-email-default.
      Repo.insert!(%FeatureConfig{
        feature: :instructor_email,
        service_config_id: other_config.id,
        section_id: nil
      })

      backfill!()

      refute Repo.exists?(from(s in ServiceConfig, where: s.name == "instructor-email-default"))
      assert [config] = global_email_configs()
      assert config.service_config_id == other_config.id
    end
  end

  describe "duplicate-named service configs" do
    test "inserts a single global feature row even if 'instructor-email-default' is duplicated" do
      model = insert_model("Primary Model")
      Repo.insert!(%ServiceConfig{name: "instructor-email-default", primary_model_id: model.id})
      Repo.insert!(%ServiceConfig{name: "instructor-email-default", primary_model_id: model.id})

      # Service config insert is a no-op (name already present); feature insert
      # must still bind to exactly one row via ORDER BY ... LIMIT 1.
      backfill!()

      assert length(global_email_configs()) == 1
    end
  end
end
