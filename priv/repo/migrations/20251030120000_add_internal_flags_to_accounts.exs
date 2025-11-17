defmodule Oli.Repo.Migrations.AddInternalFlagsToAccounts do
  use Ecto.Migration

  def change do
    alter table(:authors) do
      add :is_internal, :boolean, default: false, null: false
    end

    alter table(:users) do
      add :is_internal, :boolean, default: false, null: false
    end

    create index(:authors, [:is_internal],
             where: "is_internal = true",
             name: :authors_is_internal_true_index
           )

    create index(:users, [:is_internal],
             where: "is_internal = true",
             name: :users_is_internal_true_index
           )
  end
end
