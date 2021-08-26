defmodule Oli.Publishing.Resolver do
  @moduledoc """
  The `AuthoringResolver` and `DeliveryResolver` implement

  """

  alias Oli.Resources.Revision
  alias Oli.Publishing.HierarchyNode

  @doc """
  Resolves a revision from a list of resource ids and a given context slug.

  Ensures that the ordering of the resolved revisions matches the
  ordering of the input resource ids.  If any of the resource ids
  cannot be resolved, a nil will be present in the slot in the
  resultant list. In other words, this function can be viewed as a
  functional mapping of the list of resource ids to their resolved
  revision.
  """
  @callback from_resource_id(String.t(), [number]) :: [%Revision{}]
  @callback from_resource_id(String.t(), number) :: %Revision{}

  @doc """
  Resolves a revision from a revision slug.
  Returns nil if a revision cannot be resolved.
  """
  @callback from_revision_slug(String.t(), String.t()) :: %Revision{}

  @doc """
  Resolves the revision of the root container.
  """
  @callback root_container(String.t()) :: %Revision{}

  @doc """
  Resolves all the revisions for a given context slug.
  """
  @callback all_revisions(String.t()) :: [%Revision{}]

  @doc """
  Resolves the revisions of all containers and pages.
  """
  @callback all_revisions_in_hierarchy(String.t()) :: [%Revision{}]

  @doc """
  Reconstructs the resource hierarchy for a section or project
  ## Examples
      iex> full_hierarchy(section_or_project_slug)
      %HierarchyNode{}
  """
  @callback full_hierarchy(String.t()) :: %HierarchyNode{}

  @doc """
  Finds the parent objectives for a list of objective resource ids that
  might be child objectives.  Returns a map of the child objective resource id
  to the parent objective.  There will not be an entry in this map if
  a given objective resource id is a root objective.
  """
  @callback find_parent_objectives(String.t(), [number]) :: map()
end
