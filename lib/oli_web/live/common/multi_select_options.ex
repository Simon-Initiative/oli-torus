defmodule OliWeb.Common.MultiSelect do
  use Ecto.Schema

  embedded_schema do
    embeds_many :options, OliWeb.Common.MultiSelect.Option
  end

  defmodule Option do
    use Ecto.Schema

    embedded_schema do
      field :selected, :boolean, default: false
      field :name, :string
    end
  end

  @spec build_changeset(any()) :: Ecto.Changeset.t()
  def build_changeset(options) do
    %__MODULE__{}
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_embed(:options, options)
  end
end
