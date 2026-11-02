defmodule Oli.Delivery.Remix.State do
  @moduledoc """
  Pure, UI-agnostic state for Remix operations.

  Owned by `Oli.Delivery.Remix`. LiveViews should assign and render this state,
  but not mutate business fields directly.

  ## Material sources

  `material_sources` records where newly added hierarchy nodes came from so
  `Remix.save/2` can inherit their activities' Deep Link selections (the resource
  configuration chosen within the external tool, including its URL, custom
  parameters and optional title/description). Each entry maps a node's ephemeral
  UUID to either `{:publication, publication_id}` for
  project content or `{:section, template_id}` for template content.

  This distinction matters because templates can share a publication while
  owning different selections. Project sources inherit the chosen publication's
  configuration; template sources inherit their current section-owned records,
  without falling back to project defaults when a selection is absent.

  Adding a container also records its descendants' origins. For template sources,
  only nodes in that template's visible curriculum are eligible. At save time,
  retained pages supply the activity references to initialize, preserving existing
  destination selections. UUIDs keep provenance attached when a node is moved;
  entries for removed nodes are ignored because those nodes are no longer in the
  saved hierarchy.

  This map exists only during remix editing and is not persisted. Publication
  pins remain in `pinned_project_publications`; inherited selections become
  independently owned destination Deep Link records.

  See docs/features/refactor_remix/{prd.md,fdd.md} for context and constraints.
  """

  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Delivery.Remix.Source
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing.Publication

  @enforce_keys [
    :section,
    :hierarchy,
    :active,
    :pinned_project_publications,
    :available_sources
  ]
  defstruct section: nil,
            hierarchy: nil,
            previous_hierarchy: nil,
            active: nil,
            selected: nil,
            has_unsaved_changes: false,
            pinned_project_publications: %{},
            available_sources: [],
            # Added node UUID => chosen project publication or template section.
            material_sources: %{},
            # listing controls are UI-hints but kept here to keep transitions pure/deterministic
            pages: %{text_filter: "", limit: 5, offset: 0, sort_by: :title, sort_order: :asc},
            publications: %{
              text_filter: "",
              limit: 5,
              offset: 0,
              sort_by: :title,
              sort_order: :asc
            }

  @type t :: %__MODULE__{
          section: Section.t(),
          hierarchy: HierarchyNode.t(),
          previous_hierarchy: HierarchyNode.t() | nil,
          active: HierarchyNode.t(),
          selected: HierarchyNode.t() | nil,
          has_unsaved_changes: boolean(),
          pinned_project_publications: %{optional(integer()) => Publication.t()},
          available_sources: [Source.t()],
          material_sources: %{optional(String.t()) => {:publication | :section, integer()}},
          pages: map(),
          publications: map()
        }
end
