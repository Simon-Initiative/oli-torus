defmodule Oli.Repo.Migrations.AddOnDeleteToSectionAssociations do
  use Ecto.Migration

  def change do
    alter table(:enrollments) do
      modify :section_id, references(:sections, on_delete: :delete_all),
        from: references(:sections)
    end

    alter table(:delivery_policies) do
      modify :section_id, references(:sections, on_delete: :delete_all),
        from: references(:sections)
    end

    alter table(:gating_conditions) do
      modify :section_id, references(:sections, on_delete: :delete_all),
        from: references(:sections)
    end

    alter table(:discounts) do
      modify :section_id, references(:sections, on_delete: :delete_all),
        from: references(:sections)
    end

    alter table(:payments) do
      modify :section_id, references(:sections, on_delete: :delete_all),
        from: references(:sections)

      modify :enrollment_id, references(:enrollments, on_delete: :delete_all),
        from: references(:enrollments)
    end

    alter table(:authors_sections) do
      modify :section_id, references(:sections, on_delete: :delete_all),
        from: references(:sections)
    end

    alter table(:section_resources) do
      modify :section_id, references(:sections, on_delete: :delete_all),
        from: references(:sections)

      modify :delivery_policy_id, references(:delivery_policies, on_delete: :delete_all),
        from: references(:delivery_policies)
    end

    alter table(:section_visibilities) do
      modify :section_id, references(:sections, on_delete: :delete_all),
        from: references(:sections)
    end

    alter table(:sections_projects_publications) do
      modify :section_id, references(:sections, on_delete: :delete_all),
        from: references(:sections)
    end

    alter table(:user_groups) do
      modify :section_id, references(:sections, on_delete: :delete_all),
        from: references(:sections)

      modify :delivery_policy_id, references(:delivery_policies, on_delete: :delete_all),
        from: references(:delivery_policies)
    end

    alter table(:resource_accesses) do
      modify :section_id, references(:sections, on_delete: :delete_all),
        from: references(:sections)
    end

    alter table(:custom_activity_logs) do
      modify :section_id, references(:sections, on_delete: :delete_all),
        from: references(:sections)

      modify :activity_attempt_id, references(:activity_attempts, on_delete: :delete_all),
        from: references(:activity_attempts)
    end

    alter table(:snapshots) do
      modify :section_id, references(:sections, on_delete: :delete_all),
        from: references(:sections)

      modify :part_attempt_id, references(:part_attempts, on_delete: :delete_all),
        from: references(:part_attempts)
    end

    alter table(:lms_grade_updates) do
      modify :resource_access_id, references(:resource_accesses, on_delete: :delete_all),
        from: references(:resource_accesses)
    end

    alter table(:resource_attempts) do
      modify :resource_access_id, references(:resource_accesses, on_delete: :delete_all),
        from: references(:resource_accesses)
    end

    alter table(:activity_attempts) do
      modify :resource_attempt_id, references(:resource_attempts, on_delete: :delete_all),
        from: references(:resource_attempts)
    end

    alter table(:part_attempts) do
      modify :activity_attempt_id, references(:activity_attempts, on_delete: :delete_all),
        from: references(:activity_attempts)
    end
  end
end
