defmodule Oli.Delivery.Remix.State do
  @moduledoc """
  Pure, UI-agnostic state for Remix operations.

  Owned by `Oli.Delivery.Remix`. LiveViews should assign and render this state,
  but not mutate business fields directly.

  See docs/features/refactor_remix/{prd.md,fdd.md} for context and constraints.
  """

  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing.Publication

  @enforce_keys [:section, :hierarchy, :active, :pinned_project_publications, :available_publications]
  defstruct section: nil,
            hierarchy: nil,
            previous_hierarchy: nil,
            active: nil,
            selected: nil,
            has_unsaved_changes: false,
            pinned_project_publications: %{},
            available_publications: [],
            # listing controls are UI-hints but kept here to keep transitions pure/deterministic
            pages: %{text_filter: "", limit: 5, offset: 0, sort_by: :title, sort_order: :asc},
            publications: %{text_filter: "", limit: 5, offset: 0, sort_by: :title, sort_order: :asc}

  @type t :: %__MODULE__{
          section: Section.t(),
          hierarchy: HierarchyNode.t(),
          previous_hierarchy: HierarchyNode.t() | nil,
          active: HierarchyNode.t(),
          selected: HierarchyNode.t() | nil,
          has_unsaved_changes: boolean(),
          pinned_project_publications: %{optional(integer()) => Publication.t()},
          available_publications: [Publication.t()],
          pages: map(),
          publications: map()
        }
end
