defmodule Oli.Delivery.Transfer do
  @moduledoc """
  The Transfer context.
  """

  import Ecto.Query, warn: false

  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Paywall
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Enrollment, Section, SectionsProjectsPublications}
  alias Oli.Repo

  @doc """
  Get the course sections to which a student's data can be transferred.
  """

  def get_sections_to_transfer_data(source_section) do
    data =
      Repo.all(
        from(
          section in Section,
          join: spp in SectionsProjectsPublications,
          on: spp.section_id == section.id,
          ## condition 1: sections must have the same base_project_id (taken from the sections table)
          where: section.base_project_id == ^source_section.base_project_id,
          select: {spp, spp.section_id, section},
          order_by: [asc: section.title]
        )
      )

    {spps, section_mapper} =
      data
      |> Enum.reduce({[], %{}}, fn {spp, section_id, section}, {spps, section_mapper} = _acc ->
        {[spp | spps], Map.put(section_mapper, section_id, section)}
      end)

    {sources_spp, targets_spp} =
      Enum.split_with(spps, fn spp -> spp.section_id == source_section.id end)

    source = Enum.into(sources_spp, %{}, fn spp -> {spp.project_id, spp.publication_id} end)

    targets_spp
    |> Enum.group_by(& &1.section_id)
    |> Enum.into(%{}, fn {section_id, sppublications} ->
      {section_id,
       Enum.into(sppublications, %{}, fn spp -> {spp.project_id, spp.publication_id} end)}
    end)
    |> Enum.filter(fn {_section_id, section_candidate_data} ->
      with true <-
             project_match?(source, section_candidate_data),
           true <-
             valid_publication_ids?(source, section_candidate_data) do
        true
      end
    end)
    |> Enum.map(fn {target_section_id, _target_section_data} ->
      section_mapper[target_section_id]
      |> Map.put(:instructors, Sections.get_instructors_for_section(target_section_id))
    end)
    |> Enum.sort_by(fn section -> section.id end)
  end

  defp project_match?(source, target) do
    ## condition 2: The source and target sections must have the same list of project_ids from the sections_projects_publications table

    Map.keys(source) |> Enum.sort() == Map.keys(target) |> Enum.sort()
  end

  defp valid_publication_ids?(source, target) do
    ## condition 3: For each project_id in the source SPP table, the publications must be contained in the target (but the target cannot have any before that)

    Enum.reduce_while(source, 0, fn {project_id, publication_id}, acc ->
      case publication_id <= target[project_id] do
        true -> {:cont, acc}
        false -> {:halt, 1}
      end
    end) == 0
  end

  ## Updates payments for current enrollment with target enrollment data if current enrollment has payments and target enrollment does not
  defp maybe_transfer_payment(current_enrollment, target_enrollment, target_section_id) do
    if Paywall.has_paid?(current_enrollment) and not Paywall.has_paid?(target_enrollment) do
      case Paywall.update_payments_for_enrollment(
             current_enrollment,
             target_enrollment,
             target_section_id
           ) do
        {changes_count, nil} when is_integer(changes_count) ->
          {:ok, "Payments successfully transfered"}

        error ->
          {:error, error}
      end
    else
      {:ok, nil}
    end
  end

  @doc """
  Transfers a student's enrollment data from one section to another.
  """

  def transfer_enrollment(current_section, current_student_id, target_section, target_student_id) do
    ## gets both enrollments (current and target)
    current_enrollment = Sections.get_enrollment(current_section.slug, current_student_id)
    target_enrollment = Sections.get_enrollment(target_section.slug, target_student_id)

    Repo.transaction(fn ->
      with {:ok, %Enrollment{}} <-
             Sections.update_enrollment(target_enrollment, %{state: current_enrollment.state}),
           {:ok, _} <-
             maybe_transfer_payment(current_enrollment, target_enrollment, target_section.id),
           {changes_count, nil} when is_integer(changes_count) <-
             Core.delete_resource_accesses_by_section_and_user(
               target_section.id,
               target_student_id
             ),
           {changes_count, nil} when is_integer(changes_count) <-
             Core.update_resource_accesses_by_section_and_user(
               current_section.id,
               current_student_id,
               target_section.id,
               target_student_id
             ) do
        {:ok, "User successfully transfered"}
      else
        error -> Repo.rollback(error)
      end
    end)
  end
end
