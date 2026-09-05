defmodule Oli.Delivery.Remix.Source do
  @moduledoc """
  An authorized source of materials for delivery remix.

  A source is deliberately distinct from a publication: product sources authorize
  access to their curated delivery hierarchy without granting access to the
  product's base project as a project source.
  """

  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing.Publications.Publication

  @enforce_keys [:key, :type, :title, :pinned_publications]
  defstruct key: nil,
            type: nil,
            title: nil,
            publication_id: nil,
            project_id: nil,
            product_id: nil,
            product_slug: nil,
            pinned_publications: %{}

  @type t :: %__MODULE__{
          key: String.t(),
          type: :project | :product,
          title: String.t(),
          publication_id: integer() | nil,
          project_id: integer() | nil,
          product_id: integer() | nil,
          product_slug: String.t() | nil,
          pinned_publications: %{optional(integer()) => Publication.t()}
        }

  @spec project(Publication.t()) :: t()
  def project(%Publication{project: %{id: project_id, title: title}} = publication) do
    %__MODULE__{
      key: "project:#{publication.id}",
      type: :project,
      title: title,
      publication_id: publication.id,
      project_id: project_id,
      pinned_publications: %{project_id => publication}
    }
  end

  @spec product(Section.t(), %{optional(integer()) => Publication.t()}) :: t()
  def product(%Section{} = product, pinned_publications) do
    %__MODULE__{
      key: "product:#{product.id}",
      type: :product,
      title: product.title,
      product_id: product.id,
      product_slug: product.slug,
      pinned_publications: pinned_publications
    }
  end

  @doc "Returns the persisted selection identity for an item from this source."
  @spec selection_identity(t(), map()) :: {:ok, {pos_integer(), pos_integer()}} | :error
  def selection_identity(%__MODULE__{type: :project, publication_id: publication_id}, %{
        resource_id: resource_id
      })
      when is_integer(publication_id) and is_integer(resource_id),
      do: {:ok, {publication_id, resource_id}}

  def selection_identity(
        %__MODULE__{type: :product, pinned_publications: pinned_publications},
        %{project_id: project_id, resource_id: resource_id}
      )
      when is_integer(project_id) and is_integer(resource_id) do
    case Map.fetch(pinned_publications, project_id) do
      {:ok, %Publication{id: publication_id}} -> {:ok, {publication_id, resource_id}}
      :error -> :error
    end
  end

  def selection_identity(_, _), do: :error
end
