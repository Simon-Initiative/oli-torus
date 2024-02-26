defmodule OliWeb.Common.MultiSelectOptions do
  use Ecto.Schema

  embedded_schema do
    embeds_many :options, OliWeb.Common.MultiSelectOptions.SelectOption
  end

  defmodule SelectOption do
    use Ecto.Schema

    embedded_schema do
      field :selected, :boolean, default: false
      field :label, :string
    end
  end

  @spec build_changeset(any()) :: Ecto.Changeset.t()
  def build_changeset(options) do
    %__MODULE__{}
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_embed(:options, options)
  end
end
