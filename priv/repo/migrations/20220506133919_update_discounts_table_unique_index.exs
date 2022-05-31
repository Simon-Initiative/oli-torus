defmodule Oli.Repo.Migrations.UpdateDiscountsTableUniqueIndex do
  use Ecto.Migration

  def change do
    create unique_index(:discounts, [:section_id, :institution_id], name: :index_discount_section_institution)
  end
end
