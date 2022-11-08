defmodule Oli.Repo.Migrations.FeatureFlags do
  use Ecto.Migration
  import Ecto.Query, warn: false

  alias Oli.Repo

  @previous_id_labels %{
    1 => "adaptivity",
    2 => "equity"
  }

  def change do
    existing_label_states =
      from(
        fs in "feature_states",
        select: %{id: fs.id, state: fs.state}
      )
      |> Repo.all()
      |> Enum.map(fn %{id: id, state: state} ->
        %{label: @previous_id_labels[id], state: state}
      end)

    drop table(:feature_states)

    flush()

    create table("feature_states", primary_key: false) do
      add :label, :string, primary_key: true
      add :state, :string
    end

    flush()

    Repo.insert_all("feature_states", existing_label_states)
  end
end
