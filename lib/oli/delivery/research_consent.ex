defmodule Oli.Delivery.ResearchConsent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "research_consent" do
    field :research_consent, Ecto.Enum, values: [:oli_form, :no_form], default: :oli_form
  end

  @doc false
  def changeset(research_consent, attrs) do
    research_consent
    |> cast(attrs, [:research_consent])
    |> validate_required([:research_consent])
  end
end
