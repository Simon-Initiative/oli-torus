defmodule Oli.Delivery.Settings.AssessmentSettings do
  import Ecto.Query

  alias Ecto.Multi
  alias Oli.Accounts.Author
  alias Oli.Delivery.Settings
  alias Oli.Delivery.Settings.AutoSubmitCustodian
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Settings.StudentException
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Repo

  def do_update(:late_policy, asmt_set_id, new_value, resources) do
    %{section: section, user: user, assessments: asmts} = resources

    changes =
      case new_value do
        :allow_late_start_and_late_submit ->
          %{late_start: :allow, late_submit: :allow}

        :allow_late_submit_but_not_late_start ->
          %{late_start: :disallow, late_submit: :allow}

        :disallow_late_start_and_late_submit ->
          %{late_start: :disallow, late_submit: :disallow}
      end

    insert_setting(:late_start, changes[:late_start], asmts, asmt_set_id, section.id, user)
    |> insert_setting(:late_submit, changes[:late_submit], asmts, asmt_set_id, section.id, user)
    |> get_section_resource(section.id, asmt_set_id)
    |> update_section_resource(changes, section.id, asmt_set_id)
    |> updated_section_resource_depot()
    |> Repo.transaction()
  end

  def do_update(key, asmt_set_id, new_value, resources) do
    %{section: section, user: user, assessments: asmts} = resources

    changes = %{key => new_value}

    insert_setting(key, new_value, asmts, asmt_set_id, section.id, user)
    |> get_section_resource(section.id, asmt_set_id)
    |> update_section_resource(changes, section.id, asmt_set_id)
    |> updated_section_resource_depot()
    |> Repo.transaction()
  end

  defp updated_section_resource_depot(multi) do
    Multi.run(multi, :updated_section_resource_depot, fn
      _repo, %{update_section_resource: section_resource} ->
        {:ok, SectionResourceDepot.update_section_resource(section_resource)}
    end)
  end

  defp get_section_resource(multi, section_id, assessment_setting_id) do
    Multi.run(multi, :get_section_resource, fn _repo, _changes ->
      with section_resource = %SectionResource{} <-
             SectionResourceDepot.get_section_resource(section_id, assessment_setting_id) do
        {:ok, section_resource}
      else
        _nil ->
          {:error, "Could not find section resource"}
      end
    end)
  end

  defp update_section_resource(%Multi{} = multi, changes, section_id, asmt_set_id) do
    Multi.update(multi, :update_section_resource, fn %{get_section_resource: section_resource} ->
      case changes do
        %{late_submit: :allow} -> AutoSubmitCustodian.cancel(section_id, asmt_set_id, nil)
        _others -> nil
      end

      SectionResource.changeset(section_resource, changes)
    end)
  end

  defp insert_setting(
         %Multi{} = multi \\ Multi.new(),
         key,
         new_value,
         asmts,
         asmt_set_id,
         section_id,
         user
       ) do
    Multi.run(multi, {:insert_setting, key}, fn _repo, _changes ->
      old_value = get_old_value(asmts, asmt_set_id, key)

      Settings.insert_settings_change(%{
        resource_id: asmt_set_id,
        section_id: section_id,
        user_id: user.id,
        user_type: get_user_type(user),
        key: "#{key}",
        new_value: "#{new_value}",
        old_value: "#{old_value}"
      })
    end)
  end

  def get_student_exceptions(section_id) do
    StudentException
    |> where(section_id: ^section_id)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Retrieves all graded assessments (pages) for a given section with their settings and parent container information.

  Each assessment includes:
  - Basic assessment information (name, resource_id, etc.)
  - Combined settings from revision, section resource, and global defaults
  - A formatted display name with container label and numbering (if applicable)
  - Exception count for the assessment

  The display name format:
  - If the assessment's parent is the root container: just the page title
  - If the parent is a non-root container: "<container_label> <numbering_index>: <page title>"
    (e.g., "Unit 1: Introduction to Chemistry" or "Module 2: Quiz")

  Container labels respect customizations from the section (e.g., "Unidad", "Módulo", "Sección")
  and fall back to defaults ("Unit", "Module", "Section") if not customized.

  Uses `Sections.get_parent_containers_map/2` and `Sections.name_with_container_label/3` for
  container relationship lookups and display name formatting.

  ## Parameters
    - `section` - The section struct containing the section to get assessments for
    - `student_exceptions` - A list of student exception records to calculate exception counts

  ## Returns
    A list of assessment maps, each containing:
    - `name` - The original page title
    - `name_with_container_label` - The formatted display name with container context
    - `resource_id` - The resource ID of the assessment
    - `index` - The sequential index of the assessment (not the numbering index)
    - `scheduling_type` - The scheduling type for the assessment
    - `password` - The password for the assessment (if any)
    - `exceptions_count` - The number of student exceptions for this assessment
    - All other fields from `Settings.combine/3`

  ## Examples
      iex> section = Sections.get_section_by_slug("chemistry-101")
      iex> student_exceptions = AssessmentSettings.get_student_exceptions(section.id)
      iex> assessments = AssessmentSettings.get_assessments(section, student_exceptions)
      iex> [first_assessment | _] = assessments
      iex> first_assessment.name
      "Introduction Quiz"
      iex> first_assessment.name_with_container_label
      "Unit 1: Introduction Quiz"
  """
  def get_assessments(%Oli.Delivery.Sections.Section{} = section, student_exceptions) do
    assessments = DeliveryResolver.graded_pages_revisions_and_section_resources(section.slug)

    # Get parent container info for all pages in a single query
    page_ids = Enum.map(assessments, fn {rev, _sr} -> rev.resource_id end)
    parent_containers_map = Sections.get_parent_containers_map(section.id, page_ids)
    customizations = section.customizations

    assessments
    |> Enum.with_index()
    |> Enum.map(fn {{rev, sr}, index} ->
      parent_container_info = Map.get(parent_containers_map, rev.resource_id)

      name_with_container_label =
        Sections.name_with_container_label(
          rev.title,
          parent_container_info,
          customizations
        )

      Settings.combine(rev, sr, nil)
      |> Map.merge(%{
        index: index + 1,
        name: rev.title,
        name_with_container_label: name_with_container_label,
        scheduling_type: sr.scheduling_type,
        password: sr.password,
        exceptions_count:
          Enum.count(student_exceptions, fn se -> se.resource_id == rev.resource_id end)
      })
    end)
  end

  defp get_user_type(%Author{} = _), do: :author
  defp get_user_type(_), do: :instructor

  def get_old_value(assessments_list, resource_id, key) do
    Enum.find(assessments_list, fn assessment -> assessment.resource_id == resource_id end)
    |> case do
      nil -> nil
      assessment -> Map.get(assessment, key)
    end
  end
end
