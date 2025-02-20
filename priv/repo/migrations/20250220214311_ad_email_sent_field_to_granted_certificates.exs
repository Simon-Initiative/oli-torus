defmodule Oli.Repo.Migrations.AdEmailSentFieldToGrantedCertificates do
  use Ecto.Migration

  def change do
    alter table(:granted_certificates) do
      add :student_email_sent, :boolean, default: false
    end
  end
end
