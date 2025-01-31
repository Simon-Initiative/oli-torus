defmodule Oli.Repo.Migrations.CertificatesModifyLogosToBytea do
  use Ecto.Migration

  def change do
    alter table(:certificates) do
      modify :logo1, :bytea
      modify :logo2, :bytea
      modify :logo3, :bytea
    end
  end
end
