defmodule Oli.Conversation.DefaultPrompts do
  use Ecto.Schema
  import Ecto.Query, warn: false
  import Ecto.Changeset

  @primary_key {:label, :string, autogenerate: false}
  schema "default_prompts" do
    field :prompt, :string
  end

  @doc false
  def changeset(feature, attrs \\ %{}) do
    feature
    |> cast(attrs, [
      :label,
      :prompt
    ])
    |> validate_required([
      :label,
      :prompt
    ])
  end

  def get_prompt("page_prompt"), do: do_get_prompt("page_prompt")

  defp do_get_prompt(label) do
    query = from(p in Oli.Conversation.DefaultPrompts, where: p.label == ^label)
    Oli.Repo.one(query).prompt
  end

end
