defmodule Oli.Lti_1p3.ContextRole do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :uri, :string
  end

  @doc false
  def changeset(context_role, attrs \\ %{}) do
    context_role
    |> cast(attrs, [:uri])
    |> validate_required([:uri])
  end


end
