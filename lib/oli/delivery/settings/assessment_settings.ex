defmodule Oli.Delivery.Settings.AssessmentSettings do
  alias Ecto.Multi
  alias Oli.Accounts.Author
  alias Oli.Delivery.Settings
  alias Oli.Delivery.Settings.AutoSubmitCustodian
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionResourceDepot

  def do_update(:late_policy, asmt_set_id, new_value, resources) do
    %{section: section, user: user, assessments: asmts} = resources

    case new_value do
      :allow_late_start_and_late_submit ->
        changes = %{late_start: :allow, late_submit: :allow}

        insert_settings_change(:late_start, :allow, asmts, asmt_set_id, section.id, user)
        |> insert_settings_change(:late_submit, :allow, asmts, asmt_set_id, section.id, user)
        |> get_section_resource(section.id, asmt_set_id)
        |> update_section_resource(changes, section.id, asmt_set_id)
        |> updated_section_resource_depot()

      :allow_late_submit_but_not_late_start ->
        changes = %{late_start: :disallow, late_submit: :allow}

        insert_settings_change(:late_start, :disallow, asmts, asmt_set_id, section.id, user)
        |> insert_settings_change(:late_submit, :allow, asmts, asmt_set_id, section.id, user)
        |> get_section_resource(section.id, asmt_set_id)
        |> update_section_resource(changes, section.id, asmt_set_id)
        |> updated_section_resource_depot()

      :disallow_late_start_and_late_submit ->
        changes = %{late_start: :disallow, late_submit: :disallow}

        insert_settings_change(:late_start, :disallow, asmts, asmt_set_id, section.id, user)
        |> insert_settings_change(:late_submit, :disallow, asmts, asmt_set_id, section.id, user)
        |> get_section_resource(section.id, asmt_set_id)
        |> update_section_resource(changes, section.id, asmt_set_id)
        |> updated_section_resource_depot()
    end
    |> Oli.Repo.transaction()
  end

  def do_update(key, asmt_set_id, new_value, resources) do
    %{section: section, user: user, assessments: asmts} = resources

    changes = %{key => new_value}

    insert_settings_change(key, new_value, asmts, asmt_set_id, section.id, user)
    |> get_section_resource(section.id, asmt_set_id)
    |> update_section_resource(changes, section.id, asmt_set_id)
    |> updated_section_resource_depot()
    |> Oli.Repo.transaction()
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

  defp insert_settings_change(
         %Multi{} = multi \\ Multi.new(),
         key,
         new_value,
         asmts,
         asmt_set_id,
         section_id,
         user
       ) do
    Multi.run(multi, {:insert_settings_change, key}, fn _repo, _changes ->
      old_value = get_old_value(asmts, asmt_set_id, key)

      Settings.insert_settings_change(%{
        resource_id: asmt_set_id,
        section_id: section_id,
        user_id: user.id,
        user_type: get_user_type(user),
        key: Atom.to_string(key),
        new_value: Kernel.to_string(new_value),
        old_value: Kernel.to_string(old_value)
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
