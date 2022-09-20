defmodule Oli.Repo.Migrations.DeletePublicationsTrigger do
  use Ecto.Migration

  def change do
    drop_trigger()
  end

  def drop_trigger() do
    execute """
    DROP TRIGGER IF EXISTS published_resources_tr ON public.published_resources;
    """
  end
end
