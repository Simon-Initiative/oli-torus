defmodule Oli.Delivery.Certificates do
  @moduledoc """
  The Certificates context
  """
  import Ecto.Query

  alias Oli.Accounts.Author
  alias Oli.Accounts.User
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Delivery.Sections.Certificate
  alias Oli.Delivery.Sections.GrantedCertificate
  alias Oli.Delivery.Sections.SectionResourceDepot
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

  def browse_granted_certificates(
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

  def raw_student_certificate_progress(user_id, section_id) do
    certificate =
      from(c in Certificate,
        where: c.section_id == ^section_id,
        left_join: gc in assoc(c, :granted_certificate),
        on: gc.user_id == ^user_id,
        select:
          merge(
            map(c, ^Certificate.__schema__(:fields)),
            %{granted_certificate_state: gc.state}
          )
      )
      |> Repo.one()

    required_assignment_ids =
      case certificate.assessments_apply_to do
        :all ->
          # if no assignments list is provided
          # we use the same logic applied in OliWeb.Delivery.Student.AssignmentsLive
          # to calculate the total count and completed count
          raw_assignments = SectionResourceDepot.graded_pages(section_id, hidden: false)
          Enum.map(raw_assignments, & &1.resource_id)

        :custom ->
          certificate.custom_assessments
      end

    if certificate.granted_certificate_state == :earned do
      required_assignment_ids_count = Enum.count(required_assignment_ids)

      %{
        discussion_posts: %{
          completed: certificate.required_discussion_posts,
          total: certificate.required_discussion_posts
        },
        class_notes: %{
          completed: certificate.required_class_notes,
          total: certificate.required_class_notes
        },
        required_assignments: %{
          completed: required_assignment_ids_count,
          total: required_assignment_ids_count
        }
      }
    else
      %{
        discussion_posts:
          raw_required_discussion_posts_completion(
            user_id,
            section_id,
            certificate.required_discussion_posts
          ),
        class_notes:
          raw_required_class_notes_completion(
            user_id,
            section_id,
            certificate.required_class_notes
          ),
        required_assignments:
          raw_required_assignments_completion(
            user_id,
            section_id,
            required_assignment_ids,
            certificate.min_percentage_for_completion
          )
      }
    end
  end

  @doc """
  Count the number of discussion posts for a user in a section

  Criteria:
  Any and all discussion posts made should count toward completion despite approval/visibility/thread.
  A second reply would count as a second discussion post.
  """
  def user_certificate_discussion_posts_count(user_id, section_id) do
    from(p in Oli.Resources.Collaboration.Post,
      where:
        p.user_id == ^user_id and p.section_id == ^section_id and
          is_nil(p.annotated_resource_id),
      select: count(p.id)
    )
    |> Repo.one()
    |> case do
      nil -> 0
      count -> count
    end
  end

  @doc """
  Count the number of class notes for a user in a section

  Criteria:
  Only the public “class notes” count toward completion (so not “My Notes”).
  Multiple replies should also be considered as multiple notes.
  """
  def user_certificate_class_notes_count(user_id, section_id) do
    from(p in Oli.Resources.Collaboration.Post,
      where:
        p.user_id == ^user_id and p.section_id == ^section_id and p.visibility == :public and
          not is_nil(p.annotated_resource_id),
      select: count(p.id)
    )
    |> Repo.one()
    |> case do
      nil -> 0
      count -> count
    end
  end

  @doc """
  Counts the number of assignments that exceed the required_percentage.
  Students must get at least that percentage on each of the required_assignment_ids to earn the specified certificate.

  - if the `required_percentage` provided corresponds to the min_percentage_for_distinction,
  we are aiming to validate if the certificate of completion should be issued.

  - if the `required_percentage` provided corresponds to the min_percentage_for_completion,
  we are aiming to validate if the certificate with distinction should be issued.
  """

  def completed_assignments_count(
        user_id,
        section_id,
        required_assignment_ids,
        required_percentage
      ) do
    from(ra in ResourceAccess,
      where:
        ra.resource_id in ^required_assignment_ids and ra.section_id == ^section_id and
          ra.user_id == ^user_id and not is_nil(ra.score),
      group_by: ra.resource_id,
      select:
        fragment(
          "SUM(CASE WHEN ? / ? * 100 >= ? THEN 1 ELSE 0 END)",
          ra.score,
          ra.out_of,
          ^required_percentage
        )
    )
    |> Repo.one()
    |> case do
      nil -> 0
      count -> count
    end
  end

  defp raw_required_discussion_posts_completion(
         _student_id,
         _section_id,
         required_discussion_posts
       )
       when required_discussion_posts in [nil, 0],
       do: %{completed: 0, total: 0}

  defp raw_required_discussion_posts_completion(user_id, section_id, required_discussion_posts) do
    %{
      completed: user_certificate_discussion_posts_count(user_id, section_id),
      total: required_discussion_posts
    }
  end

  defp raw_required_class_notes_completion(_user_id, _section_id, required_class_notes)
       when required_class_notes in [nil, 0],
       do: %{completed: 0, total: 0}

  defp raw_required_class_notes_completion(user_id, section_id, required_class_notes) do
    %{
      completed: user_certificate_class_notes_count(user_id, section_id),
      total: required_class_notes
    }
  end

  defp raw_required_assignments_completion(
         user_id,
         section_id,
         required_assignment_ids,
         min_percentage_for_completion
       ) do
    %{
      completed:
        completed_assignments_count(
          user_id,
          section_id,
          required_assignment_ids,
          min_percentage_for_completion
        ),
      total: Enum.count(required_assignment_ids)
    }
  end
end
