defmodule Oli.Repo.Migrations.ReallyDeleteTrigger do
  use Ecto.Migration

  def change do
    drop_trigger()
  end

  def drop_trigger() do
    execute """
    DROP TRIGGER IF EXISTS publications_tr ON public.publications;
    """
  end
end
