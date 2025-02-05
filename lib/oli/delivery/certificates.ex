defmodule Oli.Delivery.Certificates do
  @moduledoc """
  The Certificates context
  """
  import Ecto.Query

  alias Oli.Accounts.Author
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.Certificate
  alias Oli.Delivery.Sections.GrantedCertificate
  alias Oli.Repo
  alias Oli.Repo.Paging
  alias Oli.Repo.Sorting

  @doc """
  Creates a certificate.

  ## Examples
      iex> create(%{field: value})
      {:ok, %Certificate{}}

      iex> create(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create(attrs) do
    attrs |> Certificate.changeset() |> Repo.insert()
  end

  @doc """
  Retrieves a certificate by the id.

  ## Examples
  iex> get_certificate(1)
  %Certificate{}

  iex> get_certificate(123)
  nil
  """
  def get_certificate(certificate_id), do: Repo.get(Certificate, certificate_id)

  @doc """
  Retrieves a certificate by the given params.

  ## Examples
  iex> get_certificate_by(%{title: "example"})
  %Certificate{}
  """

  def get_certificate_by(params), do: Repo.get_by(Certificate, params)

  @doc """
  Retrieves all granted certificates by section slug.
  """

  def get_granted_certificates_by_section_slug(section_slug) do
    GrantedCertificate
    |> join(:inner, [gc], c in assoc(gc, :certificate))
    |> join(:inner, [gc, c], s in assoc(c, :section))
    |> join(:inner, [gc, c, s], u in assoc(gc, :user))
    |> join(:left, [gc, c, s, u], u1 in User,
      on: u1.id == gc.issued_by and gc.issued_by_type == :user
    )
    |> join(:left, [gc, c, s, u, u1], a in Author,
      on: a.id == gc.issued_by and gc.issued_by_type == :author
    )
    |> where([gc, c, s, u, u1, a], s.slug == ^section_slug)
    |> select(
      [gc, c, s, u, u1, a],
      %{
        recipient: %{
          id: u.id,
          name: u.name,
          given_name: u.given_name,
          family_name: u.family_name,
          email: u.email
        },
        issued_at: gc.issued_at,
        issuer: %{
          name: coalesce(u1.name, a.name),
          given_name: coalesce(u1.given_name, a.given_name),
          family_name: coalesce(u1.family_name, a.family_name)
        },
        guid: gc.guid
      }
    )
    |> Repo.all()
  end

  @doc """
  Browse granted certificate records.
  """

  def browser_granted_certificates(
        %Paging{limit: limit, offset: offset},
        %Sorting{direction: direction, field: field},
        text_search,
        section_id
      ) do
    query =
      GrantedCertificate
      |> join(:inner, [gc], c in assoc(gc, :certificate))
      |> join(:inner, [gc, c], s in assoc(c, :section))
      |> join(:inner, [gc, c, s], u in assoc(gc, :user))
      |> join(:left, [gc, c, s, u], u1 in User,
        on: u1.id == gc.issued_by and gc.issued_by_type == :user
      )
      |> join(:left, [gc, c, s, u, u1], a in Author,
        on: a.id == gc.issued_by and gc.issued_by_type == :author
      )
      |> where([gc, c, s, u, u1, a], s.id == ^section_id)
      |> offset(^offset)
      |> limit(^limit)
      |> select(
        [gc, c, s, u, u1, a],
        %{
          recipient: %{
            id: u.id,
            name: u.name,
            given_name: u.given_name,
            family_name: u.family_name,
            email: u.email
          },
          issued_at: gc.issued_at,
          issuer: %{
            name: coalesce(u1.name, a.name),
            given_name: coalesce(u1.given_name, a.given_name),
            family_name: coalesce(u1.family_name, a.family_name)
          },
          guid: gc.guid,
          total_count: fragment("count(*) OVER()")
        }
      )

    filter_by_text =
      with false <- is_nil(text_search),
           text_search when text_search != "" <- String.trim(text_search) do
        dynamic(
          [gc, c, s, u, u1, a],
          ilike(u.name, ^"%#{text_search}%") or
            ilike(u.email, ^"%#{text_search}%") or
            ilike(u.given_name, ^"%#{text_search}%") or
            ilike(u.family_name, ^"%#{text_search}%") or
            ilike(a.name, ^"%#{text_search}%") or
            ilike(a.given_name, ^"%#{text_search}%") or
            ilike(a.family_name, ^"%#{text_search}%") or
            ilike(u1.name, ^"%#{text_search}%") or
            ilike(u1.given_name, ^"%#{text_search}%") or
            ilike(u1.family_name, ^"%#{text_search}%")
        )
      else
        _ -> true
      end

    query = query |> where(^filter_by_text)

    query =
      case field do
        :recipient -> order_by(query, [gc, c, s, u, u1, a], {^direction, u.name})
        :issuer -> order_by(query, [gc, c, s, u, u1, a], {^direction, coalesce(u1.name, a.name)})
        _ -> order_by(query, [gc, c, s, u, u1, a], {^direction, field(gc, ^field)})
      end

    Repo.all(query)
  end
end
