defmodule Oli.Resources.Collaboration.PostContent do
  use Ecto.Schema

  import Ecto.Changeset

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field :message, :string, default: ""
  end

  def changeset(post_content, attrs \\ %{})

  def changeset(post_content, %Oli.Resources.Collaboration.PostContent{} = attrs) do
    # if attrs is given as a struct, then convert it to a map in order to process
    changeset(post_content, Map.from_struct(attrs))
  end

  def changeset(post_content, attrs) do
    post_content
    |> cast(attrs, [
      :message
    ])
    |> validate_required([:message])
  end
end
