defmodule Oli.Delivery.Sections.SecureDeliverySettingsTest do
  use Oli.DataCase, async: false
  import Oli.Factory
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Settings.AssessmentSettings
  alias Oli.Delivery.Sections.SectionResource

  setup do
    previous = Application.fetch_env(:oli, :supports_secure_delivery)
    Application.put_env(:oli, :supports_secure_delivery, true)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:oli, :supports_secure_delivery, value)
        :error -> Application.delete_env(:oli, :supports_secure_delivery)
      end
    end)

    section = insert(:section)
    instructor = insert(:user)

    {:ok, _} =
      Sections.enroll(instructor.id, section.id, [
        Lti_1p3.Roles.ContextRoles.get_role(:context_instructor)
      ])

    sr = insert(:section_resource, section: section, graded: true, resource_type_id: 1)
    %{section: section, instructor: instructor, sr: sr}
  end

  test "default, supported edits and combined section-only projection", ctx do
    refute ctx.sr.secure_delivery
    assert {:ok, %{assessment: %{secure_delivery: true}}} = change_setting(ctx, true)
    sr = Repo.get!(SectionResource, ctx.sr.id)
    assert SectionResource.to_map(sr).secure_delivery
    revision = %Oli.Resources.Revision{content: %{}}
    assert Oli.Delivery.Settings.combine(revision, sr, nil).secure_delivery
    refute :secure_delivery in Oli.Delivery.Settings.StudentException.__schema__(:fields)

    assert Repo.exists?(
             from c in Oli.Delivery.Settings.SettingsChanges,
               where:
                 c.section_id == ^ctx.section.id and c.key == "secure_delivery" and
                   c.new_value == "true"
           )
  end

  test "unsupported enabling and forged user/target are rejected", ctx do
    Application.put_env(:oli, :supports_secure_delivery, false)
    assert {:error, :secure_delivery_unsupported} = change_setting(ctx, true)
    Application.put_env(:oli, :supports_secure_delivery, true)
    assert {:error, :not_authorized} = change_setting(%{ctx | instructor: insert(:user)}, true)
    Repo.update_all(from(sr in SectionResource, where: sr.id == ^ctx.sr.id), set: [graded: false])
    assert {:error, :invalid_secure_delivery_target} = change_setting(ctx, true)
  end

  test "stored policy survives disablement and unrelated edits", ctx do
    assert {:ok, _} = change_setting(ctx, true)
    Application.put_env(:oli, :supports_secure_delivery, false)
    sr = Repo.get!(SectionResource, ctx.sr.id)
    assert {:ok, sr} = Sections.update_section_resource(sr, %{allow_hints: true})
    assert sr.secure_delivery
    assert {:ok, _} = change_setting(ctx, false)
  end

  test "changeset rejects null, unsupported and ungraded enables", ctx do
    refute SectionResource.changeset(ctx.sr, %{secure_delivery: nil}).valid?
    refute SectionResource.changeset(%{ctx.sr | graded: false}, %{secure_delivery: true}).valid?

    refute SectionResource.changeset(%{ctx.sr | resource_type_id: 2}, %{secure_delivery: true}).valid?

    Application.put_env(:oli, :supports_secure_delivery, false)
    refute SectionResource.changeset(ctx.sr, %{secure_delivery: true}).valid?
  end

  defp change_setting(ctx, value) do
    AssessmentSettings.update(
      ctx.section,
      ctx.instructor,
      ctx.sr.resource_id,
      %{secure_delivery: value},
      %{assessments: [%{resource_id: ctx.sr.resource_id, secure_delivery: false}]}
    )
  end
end
