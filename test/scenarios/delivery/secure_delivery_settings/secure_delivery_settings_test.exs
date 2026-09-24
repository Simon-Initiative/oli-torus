defmodule Oli.Scenarios.SecureDeliverySettingsTest do
  use Oli.DataCase
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Blueprint, Section, SectionResource}
  alias Oli.Delivery.Settings.AssessmentSettings
  alias Oli.Scenarios

  @tag capture_log: true
  test "policy copy and publication refresh use real domain workflows" do
    previous = Application.fetch_env(:oli, :supports_secure_delivery)
    Application.put_env(:oli, :supports_secure_delivery, true)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:oli, :supports_secure_delivery, value)
        :error -> Application.delete_env(:oli, :supports_secure_delivery)
      end
    end)

    path = Path.join(__DIR__, "policy.scenario.yaml")
    assert :ok = Scenarios.validate_file(path)
    result = Scenarios.execute_file(path, Oli.Scenarios.RuntimeOpts.build())
    assert result.errors == []
    assert Enum.all?(result.verifications, & &1.passed)
  end

  @doc "Enables section policy and verifies that duplication preserves it."
  def enable_and_copy(state) do
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
    assert {:ok, copy_when_disabled} = Blueprint.duplicate(section)

    assert Sections.get_section_resource(copy_when_disabled.id, assessment.resource_id).secure_delivery
    assert Repo.aggregate(Section, :count) == count + 1
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
