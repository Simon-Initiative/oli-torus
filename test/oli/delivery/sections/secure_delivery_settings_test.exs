defmodule Oli.Delivery.Sections.SecureDeliverySettingsTest do
  use Oli.DataCase, async: false
  import Oli.Factory
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Settings.AssessmentSettings
  alias Oli.Delivery.Sections.SectionResource
  alias Lti_1p3.Roles.PlatformRoles

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

  test "LMS context administrator without instructor role can edit secure delivery", ctx do
    administrator = insert(:user)

    {:ok, _} =
      Sections.enroll(administrator.id, ctx.section.id, [
        Lti_1p3.Roles.ContextRoles.get_role(:context_administrator)
      ])

    refute Sections.is_instructor?(administrator, ctx.section.slug)
    assert Sections.is_admin?(Repo.preload(administrator, :platform_roles), ctx.section.slug)

    assert {:ok, _} = change_setting(%{ctx | instructor: administrator}, true)
    assert Repo.get!(SectionResource, ctx.sr.id).secure_delivery
    assert {:ok, _} = change_setting(%{ctx | instructor: administrator}, false)
    refute Repo.get!(SectionResource, ctx.sr.id).secure_delivery
  end

  test "institution administrator without instructor role can edit secure delivery", ctx do
    administrator = insert(:user)

    {:ok, administrator} =
      Oli.Accounts.update_user_platform_roles(administrator, [
        PlatformRoles.get_role(:institution_administrator)
      ])

    refute Sections.is_instructor?(administrator, ctx.section.slug)
    assert Sections.is_admin?(administrator, ctx.section.slug)
    assert {:ok, _} = change_setting(%{ctx | instructor: administrator}, true)
    assert Repo.get!(SectionResource, ctx.sr.id).secure_delivery
  end

  test "unsupported enabling and forged user/target are rejected", ctx do
    Application.put_env(:oli, :supports_secure_delivery, false)
    assert {:error, :secure_delivery_unsupported} = change_setting(ctx, true)
    Application.put_env(:oli, :supports_secure_delivery, true)
    assert {:error, :not_authorized} = change_setting(%{ctx | instructor: insert(:user)}, true)
    Repo.update_all(from(sr in SectionResource, where: sr.id == ^ctx.sr.id), set: [graded: false])
    assert {:error, :invalid_secure_delivery_target} = change_setting(ctx, true)
  end

  for {description, attrs} <- [
        {"becomes ungraded", %{graded: false}},
        {"changes resource type", %{resource_type_id: 2}}
      ] do
    test "policy can be disabled after its target #{description}", ctx do
      assert {:ok, _} = change_setting(ctx, true)
      sr = Repo.get!(SectionResource, ctx.sr.id)
      assert {:ok, sr} = Sections.update_section_resource(sr, unquote(Macro.escape(attrs)))
      assert sr.secure_delivery
      Oli.Delivery.Sections.SectionResourceDepot.update_section_resource(sr)
      ctx = %{ctx | sr: sr}

      assert {:error, :invalid_secure_delivery_target} = change_setting(ctx, true)
      Application.put_env(:oli, :supports_secure_delivery, false)
      assert {:ok, %{assessment: %{secure_delivery: false}}} = change_setting(ctx, false)
      refute Repo.get!(SectionResource, sr.id).secure_delivery
    end
  end

  test "enabling and disabling require a resource in the section", ctx do
    other_resource = insert(:section_resource)
    ctx = %{ctx | sr: other_resource}

    for value <- [true, false] do
      assert {:error, :invalid_secure_delivery_target} = change_setting(ctx, value)
    end
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
      %{
        assessments: [%{resource_id: ctx.sr.resource_id, secure_delivery: ctx.sr.secure_delivery}]
      }
    )
  end
end
