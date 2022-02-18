defmodule Oli.SectionInvitesTest do
  use Oli.DataCase
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{SectionInvite, SectionInvites}

  @section_attrs %{
    open_and_free: true,
    requires_enrollment: true,
    registration_open: true,
    start_date: ~U[2010-04-17 00:00:00.000000Z],
    end_date: ~U[2010-05-17 00:00:00.000000Z],
    timezone: "some timezone",
    title: "some title",
    context_id: "context_id"
  }

  describe "section_invites" do
    setup do
      map = Seeder.base_project_with_resource2()

      {:ok, section} =
        @section_attrs
        |> Map.put(:institution_id, map.institution.id)
        |> Map.put(:base_project_id, map.project.id)
        |> Sections.create_section()

      {:ok, section_invite} = SectionInvites.create_default_section_invite(section.id)

      {:ok,
       Map.merge(map, %{
         section: section,
         section_invite: section_invite
       })}
    end

    test "default section invite is valid", %{section_invite: section_invite, section: section} do
      assert section_invite.section_id == section.id
      assert is_binary(section_invite.slug)
      assert is_struct(section_invite.date_expires)

      # Test the changeset. Make sure it requires a section_id and date_expires
      {:error, _} =
        SectionInvite.changeset(%SectionInvite{})
        |> Repo.insert()

      {:error, _} =
        SectionInvite.changeset(%SectionInvite{}, %{date_expires: now()})
        |> Repo.insert()

      {:error, _} =
        SectionInvite.changeset(%SectionInvite{}, %{section_id: section.id})
        |> Repo.insert()

      {:ok, _invite} =
        SectionInvite.changeset(%SectionInvite{}, %{section_id: section.id, date_expires: now()})
        |> Repo.insert()
    end

    test "link_expired?/1 determines whether the invite is expired", %{
      section_invite: section_invite,
      section: section
    } do
      assert SectionInvites.link_expired?(section_invite) == false
      assert SectionInvites.link_expired?(section_invite.slug) == false

      {:ok, invite} =
        SectionInvite.changeset(%SectionInvite{}, %{section_id: section.id, date_expires: now()})
        |> Repo.insert()

      assert SectionInvites.link_expired?(invite) == true
      assert SectionInvites.link_expired?(invite.slug) == true

      assert SectionInvites.link_expired?(nil) == true
    end

    test "getters work", %{section_invite: section_invite, section: section} do
      refute SectionInvites.get_section_invite("other_invite")
      refute SectionInvites.get_section_by_invite_slug("other_invite")

      assert SectionInvites.get_section_invite(section_invite.slug) == section_invite
      assert SectionInvites.get_section_by_invite_slug(section_invite.slug).id == section.id
    end

    test "expire_after/3 works", %{section: section} do
      date = now()
      after_one_day = SectionInvites.expire_after(nil, date, :one_day)
      after_one_week = SectionInvites.expire_after(nil, date, :one_week)
      start_date = SectionInvites.expire_after(section, nil, :section_start)
      end_date = SectionInvites.expire_after(section, nil, :section_end)

      assert NaiveDateTime.compare(after_one_day, date) == :gt
      assert NaiveDateTime.compare(after_one_week, date) == :gt
      assert NaiveDateTime.compare(after_one_week, after_one_day) == :gt
      assert NaiveDateTime.compare(start_date, date) == :lt
      assert NaiveDateTime.compare(end_date, date) == :lt
      assert NaiveDateTime.compare(start_date, end_date) == :lt
    end
  end
end
