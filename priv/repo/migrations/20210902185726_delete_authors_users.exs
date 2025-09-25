defmodule Oli.Repo.Migrations.DeleteAuthorsUsers do
  use Ecto.Migration

  def up do
    # users
    drop(constraint(:user_identities, "user_identities_user_id_fkey"))

    alter table(:user_identities) do
      modify(:user_id, references(:users, on_delete: :delete_all))
    end

    drop(constraint(:enrollments, "enrollments_user_id_fkey"))

    alter table(:enrollments) do
      modify(:user_id, references(:users, on_delete: :delete_all))
    end

    drop(constraint(:enrollments_context_roles, "enrollments_context_roles_enrollment_id_fkey"))

    alter table(:enrollments_context_roles) do
      modify(:enrollment_id, references(:enrollments, on_delete: :delete_all))
    end

    drop(constraint(:resource_accesses, "resource_accesses_user_id_fkey"))

    alter table(:resource_accesses) do
      modify(:user_id, references(:users, on_delete: :nilify_all))
    end

    drop(constraint(:snapshots, "snapshots_user_id_fkey"))

    alter table(:snapshots) do
      modify(:user_id, references(:users, on_delete: :nilify_all))
    end

    drop(constraint(:users_platform_roles, "users_platform_roles_user_id_fkey"))

    alter table(:users_platform_roles) do
      modify(:user_id, references(:users, on_delete: :delete_all))
    end

    drop(constraint(:consent_cookies, "consent_cookies_user_id_fkey"))

    alter table(:consent_cookies) do
      modify(:user_id, references(:users, on_delete: :delete_all))
    end

    drop(constraint(:users, "users_author_id_fkey"))

    alter table(:users) do
      modify :author_id, references(:authors, on_delete: :nilify_all)
    end

    drop(constraint(:revisions, "revisions_author_id_fkey"))

    alter table(:revisions) do
      modify :author_id, references(:authors, on_delete: :nilify_all)
    end

    drop(constraint(:authors_projects, "authors_projects_author_id_fkey"))

    alter table(:authors_projects) do
      modify :author_id, references(:authors, on_delete: :delete_all)
    end

    drop(constraint(:project_visibilities, "project_visibilities_author_id_fkey"))

    alter table(:project_visibilities) do
      modify :author_id, references(:authors, on_delete: :delete_all)
    end
  end

  def down() do
    # users
    drop(constraint(:user_identities, "user_identities_user_id_fkey"))

    alter table(:user_identities) do
      modify(:user_id, references(:users, on_delete: :nothing))
    end

    drop(constraint(:enrollments, "enrollments_user_id_fkey"))

    alter table(:enrollments) do
      modify(:user_id, references(:users, on_delete: :nothing))
    end

    drop(constraint(:enrollments_context_roles, "enrollments_context_roles_enrollment_id_fkey"))

    alter table(:enrollments_context_roles) do
      modify(:enrollment_id, references(:enrollments, on_delete: :nothing))
    end

    drop(constraint(:resource_accesses, "resource_accesses_user_id_fkey"))

    alter table(:resource_accesses) do
      modify(:user_id, references(:users, on_delete: :nothing))
    end

    drop(constraint(:snapshots, "snapshots_user_id_fkey"))

    alter table(:snapshots) do
      modify(:user_id, references(:users, on_delete: :nothing))
    end

    drop(constraint(:users_platform_roles, "users_platform_roles_user_id_fkey"))

    alter table(:users_platform_roles) do
      modify(:user_id, references(:users, on_delete: :nothing))
    end

    drop(constraint(:consent_cookies, "consent_cookies_user_id_fkey"))

    alter table(:consent_cookies) do
      modify(:user_id, references(:users, on_delete: :nothing))
    end

    drop(constraint(:users, "users_author_id_fkey"))

    alter table(:users) do
      modify :author_id, references(:authors, on_delete: :nothing)
    end

    drop(constraint(:revisions, "revisions_author_id_fkey"))

    alter table(:revisions) do
      modify :author_id, references(:authors, on_delete: :nothing)
    end

    drop(constraint(:authors_projects, "authors_projects_author_id_fkey"))

    alter table(:authors_projects) do
      modify :author_id, references(:authors, on_delete: :nothing)
    end

    drop(constraint(:project_visibilities, "project_visibilities_author_id_fkey"))

    alter table(:project_visibilities) do
      modify :author_id, references(:authors, on_delete: :nothing)
    end
  end
end
