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
  alias Oli.Delivery.Sections.Section
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
  Updates a certificate.

  ## Examples
  iex> update_certificate(%Certificate{}, %{field: value})
  {:ok, %Certificate{}}

  iex> update_certificate(%Certificate{}, %{field: bad_value})
  {:error, %Ecto.Changeset{}}
  """
  def update_certificate(certificate, attrs) do
    certificate
    |> Certificate.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Retrieves all granted certificates by section id.
  In case the section is a blueprint, it will return all granted certificates by all courses created based on that product.

  The opts filter_by_state can be provided to filter the granted certificates by their state.
  """

  def get_granted_certificates_by_section_id(section_id, opts \\ [filter_by_state: []]) do
    maybe_filter_by_earned_state =
      if opts[:filter_by_state] == [] do
        dynamic([gc], true)
      else
        dynamic([gc], gc.state in ^opts[:filter_by_state])
      end

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
    |> where([gc, c, s, u, u1, a], s.id == ^section_id or s.blueprint_id == ^section_id)
    |> where(^maybe_filter_by_earned_state)
    |> select(
      [gc, c, s, u, u1, a],
      %{
        id: gc.id,
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
        state: gc.state
      }
    )
    |> Repo.all()
  end

  @doc """
  Browse granted certificate records.
  In case the section is a blueprint, it will return all granted certificates by all courses created based on that product.
  """

  def browse_granted_certificates(
        %Paging{limit: limit, offset: offset},
        %Sorting{direction: direction, field: field},
        text_search,
        %Section{id: section_id, type: type}
      ) do
    # if the section is blueprint (a product) we search for the granted certificates
    # in all the courses created based on that product
    filter_by_section_or_blueprint =
      if type == :blueprint do
        dynamic([gc, c, s, u, u1, a], s.blueprint_id == ^section_id or s.id == ^section_id)
      else
        dynamic([gc, c, s, u, u1, a], s.id == ^section_id)
      end

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
      |> where(^filter_by_section_or_blueprint)
      |> where([gc, c, s, u, u1, a], gc.state == :earned)
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

  @doc """
  Returns the raw progress of a student in a certificate, detailed by the completion of discussion posts, class notes, and required assignments.

  Returns a map with the following keys:
  %{discussion_posts: %{completed: integer, total: integer},
    class_notes: %{completed: integer, total: integer},
    required_assignments: %{completed: integer, total: integer}}

  If the certificate has been earned, the total count will be equal to the completed count (to avoid doing extra queries)
  """
  def raw_student_certificate_progress(user_id, section_id) do
    certificate =
      from(c in Certificate,
        where: c.section_id == ^section_id,
        left_join: gc in assoc(c, :granted_certificate),
        on: gc.user_id == ^user_id,
        select:
          merge(
            map(c, ^Certificate.__schema__(:fields)),
            %{granted_certificate_state: gc.state, granted_certificate_guid: gc.guid}
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
        },
        granted_certificate_guid: certificate.granted_certificate_guid,
        granted_certificate_state: certificate.granted_certificate_state
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
          ),
        granted_certificate_guid: certificate.granted_certificate_guid,
        granted_certificate_state: certificate.granted_certificate_state
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
  Counts the number of assignments that acomplish the required_percentage.
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

  @doc """
  Purges deleted assessments from the certificate by checking all defined required assessments in the certificate
  still belong to the section. If not, the assessment is removed from the certificate.
  """
  def purge_deleted_assessments_from_certificate(section) do
    with true <- section.certificate_enabled,
         %Certificate{assessments_apply_to: :custom} = certificate <-
           get_certificate_by(%{section_id: section.id}) do
      all_assessment_ids =
        SectionResourceDepot.graded_pages(section.id, hidden: false)
        |> Enum.map(& &1.resource_id)

      purged_required_assessment_ids =
        Enum.filter(certificate.custom_assessments, &(&1 in all_assessment_ids))

      update_certificate(certificate, %{
        custom_assessments: purged_required_assessment_ids
      })
    end
  end

  @doc """
  Switches the certificate to require ':custom' assessments if the certificate is set to require ':all' assessments
  by setting the custom assessments list to the list of all graded pages in the section.
  """
  def switch_certificate_to_custom_assessments(section) do
    with true <- section.certificate_enabled,
         %Certificate{assessments_apply_to: :all} = certificate <-
           get_certificate_by(%{section_id: section.id}) do
      original_required_assessment_ids =
        SectionResourceDepot.graded_pages(section.id, hidden: false)
        |> Enum.map(& &1.resource_id)

      update_certificate(certificate, %{
        assessments_apply_to: :custom,
        custom_assessments: original_required_assessment_ids
      })
    else
      _ -> {:ok, :no_switch_needed}
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
