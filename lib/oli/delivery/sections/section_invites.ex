defmodule Oli.Delivery.Sections.SectionInvites do
  import Ecto.Query, warn: false
  import Oli.Utils.Time

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Section, SectionInvite}
  alias Oli.Repo

  @doc """
  Creates a section invite with slug and expiration date of 1 week later when given a section_id.
  """
  def create_default_section_invite(section_id) do
    create_section_invite(%{
      section_id: section_id,
      date_expires: expire_after(Sections.get_section!(section_id), now(), :one_week)
    })
  end

  @doc """
  Creates a section invite with no default attrs. Requires attrs to be provided.
  """
  def create_section_invite(attrs \\ %{}) do
    %SectionInvite{}
    |> SectionInvite.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a section invite by slug.
  """
  def get_section_invite(slug) when is_binary(slug) do
    Repo.get_by(SectionInvite, slug: slug)
  end

  @doc """
  List all section invites.
  """
  def list_section_invites do
    Repo.all(SectionInvite)
  end

  @doc """
  Gets the attached section when given a section invite slug.
  """
  def get_section_by_invite_slug(section_invite_slug) when is_binary(section_invite_slug) do
    section_invite = get_section_invite(section_invite_slug)
    Sections.get_section!(section_invite.section_id)
  end

  @doc """
  Lists all the section invites for a particular section (when given a section_id).
  """
  def list_section_invites(section_id) do
    from(s in SectionInvite,
      where: s.section_id == ^section_id
    )
    |> Repo.all()
  end

  @doc """
  Determines if a user is an administrator in a given section.
  """
  def link_expired?(%SectionInvite{} = section_invite) do
    NaiveDateTime.compare(now(), section_invite.date_expires) == :gt
  end

  def link_expired?(section_invite_slug) when is_binary(section_invite_slug) do
    section_invite_slug
    |> get_section_invite()
    |> link_expired?()
  end

  @doc """
  Returns a NaiveDateTime one day or one week in the future, or
  at the section start or section end times.
  Params:
    %Section{} (optional)
    %Date (optional)
    :one_day | :one_week | :section_start | :section_end
  """
  def expire_after(_section, date, :one_day) do
    NaiveDateTime.add(date, one_day())
  end

  def expire_after(_section, date, :one_week) do
    NaiveDateTime.add(date, one_week())
  end

  def expire_after(%Section{} = section, _date, :section_start) do
    section.start_date
  end

  def expire_after(%Section{} = section, _date, :section_end) do
    section.end_date
  end

  @doc """
  A list of tuples {:key, %NaiveDateTime} where :key is
  :one_day | :one_week | :section_start | :section_end
  """
  def expire_after_options(date, section) do
    [
      {:one_day, expire_after(section, date, :one_day)},
      {:one_week, expire_after(section, date, :one_week)},
      {:section_start, expire_after(section, date, :section_start)},
      {:section_end, expire_after(section, date, :section_end)}
    ]
  end
end
