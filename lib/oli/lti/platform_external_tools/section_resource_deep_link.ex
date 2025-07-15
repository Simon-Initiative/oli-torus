defmodule Oli.Lti.PlatformExternalTools.SectionResourceDeepLink do
  @moduledoc """
  Represents a deep link resource in the context of an LTI platform external tool
  """
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :type, :title, :text]}
  schema "lti_section_resource_deep_links" do
    field :type, Ecto.Enum,
      values: [:ltiResourceLink, :ltiLink, :ltiAssignmentAndGradeServices],
      default: :ltiResourceLink

    field :url, :string
    field :title, :string
    field :text, :string
    field :custom, :map, default: %{}

    belongs_to :resource, Oli.Resources.Resource
    belongs_to :section, Oli.Delivery.Sections.Section

    timestamps()
  end

  def changeset(deep_link, attrs) do
    deep_link
    |> cast(attrs, [:type, :url, :title, :text, :custom, :resource_id, :section_id])
    |> validate_required([:type, :resource_id, :section_id])
  end
end
