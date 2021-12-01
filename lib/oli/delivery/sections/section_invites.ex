defmodule Oli.Delivery.Sections.SectionInvites do
  import Ecto.Query, warn: false
  import Oli.Utils.Time

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Section, SectionInvite}
  alias Oli.Repo

  def create_default_section_invite(section_id) do
    create_section_invite(%{
      section_id: section_id,
      date_expires: expire_after(now(), :one_week)
    })
  end

  def create_section_invite(attrs \\ %{}) do
    %SectionInvite{}
    |> SectionInvite.changeset(attrs)
    |> Repo.insert()
  end

  def get_section_invite(slug) when is_binary(slug) do
    Repo.get_by(SectionInvite, slug: slug)
  end

  def list_section_invites do
    Repo.all(SectionInvite)
  end

  def get_section_by_invite_slug(section_invite_slug) when is_binary(section_invite_slug) do
    section_invite = get_section_invite(section_invite_slug)
    Sections.get_section!(section_invite.section_id)
  end

  def list_section_invites(section_id) do
    Repo.get_by(SectionInvite, section_id: section_id)
  end

  def is_link_valid?(%SectionInvite{} = section_invite) do
    NaiveDateTime.compare(now(), section_invite.date_expires) == :lt
  end

  def is_link_valid?(section_invite_slug) when is_binary(section_invite_slug) do
    section_invite_slug
    |> get_section_invite()
    |> is_link_valid?()
  end

  def expire_after(date, :one_day) do
    NaiveDateTime.add(date, one_day())
  end

  def expire_after(date, :one_week) do
    NaiveDateTime.add(date, one_week())
  end

  def expire_after(%Section{} = section, :section_start) do
    section.start_date
  end

  def expire_after(%Section{} = section, :section_end) do
    section.end_date
  end

  def expire_after_options(date, section) do
    [
      {:one_day, expire_after(date, :one_day)},
      {:one_week, expire_after(date, :one_week)},
      {:section_start, expire_after(section, :section_start)},
      {:section_end, expire_after(section, :section_end)}
    ]
  end
end
