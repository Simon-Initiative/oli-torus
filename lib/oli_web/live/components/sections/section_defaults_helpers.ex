defmodule OliWeb.Live.Components.Sections.SectionDefaultsHelpers do
  @moduledoc """
  Shared helpers for parent LiveViews that host the section defaults components
  (AiAssistantComponent, NotesComponent, CourseDiscussionsComponent, RequiredSurvey).

  Provides:
  - `load_component_data/1` — loads the assigns needed by the components in mount
  - `handle_section_updated/3` — merges updated section into the parent's assign
  - `handle_notes_count_updated/2` — keeps collab_space_pages_count in sync
  - `handle_collab_space_config_updated/3` — keeps root config and section_resource in sync

  Used by: Products.DetailsView, Sections.OverviewView, Workspaces.CourseAuthor.Products.DetailsLive
  """

  import Phoenix.Component, only: [assign: 2]

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Section, SectionResource}
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Repo
  alias Oli.Resources.Collaboration

  @doc """
  Loads the data needed by NotesComponent, CourseDiscussionsComponent, and RequiredSurvey.
  Takes a section (blueprint or enrollable) and returns a map of assigns.
  """
  def load_component_data(%Section{} = section) do
    # Notes: load page-level collab space counts
    {collab_space_pages_count, pages_count} =
      Collaboration.count_collab_spaces_enabled_in_pages_for_section(section.slug)

    # Discussions: load root container's section_resource and collab_space_config
    root_revision = DeliveryResolver.root_container(section.slug)

    {root_section_resource, root_collab_space_config} =
      if root_revision do
        {:ok, config} =
          Collaboration.get_collab_space_config_for_page_in_section(
            root_revision.slug,
            section.slug
          )

        root_sr = Repo.get(SectionResource, section.root_section_resource_id)
        {root_sr, config}
      else
        {nil, nil}
      end

    # Required Survey: check if base project has a survey
    show_required_section_config =
      if section.required_survey_resource_id != nil or
           Sections.get_base_project_survey(section.slug) do
        true
      else
        false
      end

    %{
      collab_space_pages_count: collab_space_pages_count,
      pages_count: pages_count,
      root_section_resource: root_section_resource,
      root_collab_space_config: root_collab_space_config,
      show_required_section_config: show_required_section_config
    }
  end

  @doc """
  Merges an updated section into the parent's assign, preserving preloaded associations.
  `assign_key` is the atom key used in the parent (`:product` or `:section`).
  """
  def handle_section_updated(socket, assign_key, %Section{} = updated_section) do
    current = Map.get(socket.assigns, assign_key)

    merged =
      Map.merge(
        Map.from_struct(current),
        Map.from_struct(updated_section),
        fn _key, current_val, new_val ->
          case new_val do
            %Ecto.Association.NotLoaded{} -> current_val
            _ -> new_val
          end
        end
      )

    assign(socket, [{assign_key, struct(Section, merged)}])
  end

  @doc """
  Updates the collab_space_pages_count assign to keep NotesComponent in sync.
  """
  def handle_notes_count_updated(socket, count) do
    assign(socket, collab_space_pages_count: count)
  end

  @doc """
  Updates root_collab_space_config and root_section_resource to keep
  CourseDiscussionsComponent in sync.
  """
  def handle_collab_space_config_updated(socket, config, root_sr) do
    assign(socket,
      root_collab_space_config: config,
      root_section_resource: root_sr
    )
  end
end
