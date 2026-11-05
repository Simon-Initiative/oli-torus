defmodule Oli.Repo.Migrations.WidenCertificateDescription do
  use Ecto.Migration

  def up do
    alter table(:certificates) do
      modify :description, :text
    end
  end

  def down do
    # Refuse a rollback that would truncate or reject descriptions copied from products.
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM certificates WHERE char_length(description) > 255
      ) THEN
        RAISE EXCEPTION 'Cannot restore 255-character certificate descriptions while longer values exist';
      END IF;
    END $$;
    """

    alter table(:certificates) do
      modify :description, :string
    end
  end
end
