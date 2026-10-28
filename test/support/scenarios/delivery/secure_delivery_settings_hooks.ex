defmodule Oli.Scenarios.Delivery.SecureDeliverySettingsHooks do
  @moduledoc "Hooks shared by standalone and discovered secure-delivery policy scenarios."

  import Ecto.Query
  import ExUnit.Assertions
  import ExUnit.Callbacks, only: [on_exit: 1]

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Blueprint, CopyOptions, Section, SectionCopy, SectionResource}
  alias Oli.Delivery.Settings.AssessmentSettings
  alias Oli.Repo

  @doc "Enables section policy and verifies that duplication preserves it."
  def enable_and_copy(state) do
    previous = Application.fetch_env(:oli, :supports_secure_delivery)
    Application.put_env(:oli, :supports_secure_delivery, true)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:oli, :supports_secure_delivery, value)
        :error -> Application.delete_env(:oli, :supports_secure_delivery)
      end
    end)

    section = state.sections["assessment_settings_section"]
    instructor = state.users["instructor_1"]
    [assessment] = AssessmentSettings.get_assessments(section, [])

    {:ok, _} =
      AssessmentSettings.update(section, instructor, assessment.resource_id, %{
        secure_delivery: true
      })

    assert {:ok, copy} = Blueprint.duplicate(section, %{type: :enrollable})
    assert Sections.get_section_resource(copy.id, assessment.resource_id).secure_delivery
    Application.put_env(:oli, :supports_secure_delivery, false)
    count = Repo.aggregate(Section, :count)
    publisher_id = state.projects["assessment_settings_source"].project.publisher_id
    assert {:ok, copy_when_disabled} = Blueprint.duplicate(section, %{publisher_id: publisher_id})

    assert Sections.get_section_resource(copy_when_disabled.id, assessment.resource_id).secure_delivery
    assert Repo.aggregate(Section, :count) == count + 1

    # The current course-copy engine explicitly selects assessment settings.
    {:ok, with_settings} = CopyOptions.new([:content, :assessment_settings])

    assert {:ok, course_copy} =
             SectionCopy.copy(section, %{title: "Copy with secure policy"}, with_settings)

    assert Sections.get_section_resource(course_copy.id, assessment.resource_id).secure_delivery

    {:ok, content_only} = CopyOptions.new([:content])

    assert {:ok, reset_copy} =
             SectionCopy.copy(section, %{title: "Copy without assessment settings"}, content_only)

    refute Sections.get_section_resource(reset_copy.id, assessment.resource_id).secure_delivery
    state
  end

  @doc "Asserts existing policy survives publication refresh while support is disabled."
  def verify_preservation(state) do
    section = state.sections["assessment_settings_section"]

    resource =
      Repo.one!(
        from sr in SectionResource,
          where: sr.section_id == ^section.id and sr.graded == true
      )

    assert resource.title == "Updated Quiz"
    assert resource.secure_delivery
    state
  end
end
