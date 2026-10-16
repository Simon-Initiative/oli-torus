defmodule Oli.Lti.PlatformExternalTools.LtiSectionResourceDeepLink do
  @moduledoc """
  Represents a section-owned LTI resource link and validates portable tool selections
  (resource configurations chosen in external tools, including URL/custom metadata).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :type, :url, :title, :text]}
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

  @doc """
  Validates a selection (the resource configuration returned by the external tool)
  and extracts supported type, URL, custom, title and description fields.
  An optional URL must be HTTP(S); custom objects are preserved without reinterpretation.
  """
  @spec selection(term()) :: {:ok, map()} | {:error, :invalid_selection}
  def selection(%{"type" => "ltiResourceLink"} = item) do
    url = item["url"]
    custom = item["custom"]

    valid_url =
      case url do
        nil ->
          true

        url when is_binary(url) ->
          uri = URI.parse(url)
          uri.scheme in ["https", "http"] and is_binary(uri.host) and uri.host != ""

        _ ->
          false
      end

    case valid_url and (is_nil(custom) or is_map(custom)) and
           Enum.all?(["title", "text"], &(is_nil(item[&1]) or is_binary(item[&1]))) do
      true -> {:ok, Map.take(item, ["type", "url", "custom", "title", "text"])}
      false -> {:error, :invalid_selection}
    end
  rescue
    ArgumentError -> {:error, :invalid_selection}
  end

  def selection(_), do: {:error, :invalid_selection}
end
