defmodule Oli.Resources.Revision.IntroVideo do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :url, :string
    field :source, Ecto.Enum, values: ~w(youtube S3)a
  end

  def changeset(intro_video, attrs) do
    intro_video
    |> cast(attrs, [:url, :source])
    |> validate_required([:url, :source])
    |> maybe_validate_youtube_url()
  end

  defp maybe_validate_youtube_url(changeset) do
    case get_field(changeset, :source) do
      :youtube ->
        changeset
        |> validate_format(:url, ~r{youtube\.com|youtu\.be},
          message: "must be a valid YouTube URL"
        )

      _ ->
        changeset
    end
  end
end
