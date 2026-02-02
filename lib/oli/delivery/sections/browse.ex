defmodule Oli.Delivery.Sections.Browse do
  import Ecto.Query, warn: false

  alias Oli.Delivery.Sections.EnrollmentContextRole
  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.{Section, Enrollment, BrowseOptions, SectionsProjectsPublications}
  alias Oli.Delivery.Sections
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}

  @chars_to_replace_on_search [" ", "&", ":", ";", "(", ")", "|", "!", "'", "<", ">"]

  @doc """
    Paged, sorted, filterable queries for course sections. Joins the institution,
    the base product or project and counts the number of enrollments.
  """
  def browse_sections_query(
        %Paging{limit: limit, offset: offset},
        %Sorting{direction: direction, field: field},
        %BrowseOptions{} = options
      ) do
    # text search
    filter_by_text =
      if options.text_search == "" or is_nil(options.text_search) do
        true
      else
        # allow to search by prefix
        search_term =
          options.text_search
          |> String.split(@chars_to_replace_on_search, trim: true)
          |> Enum.map(fn x -> x <> ":*" end)
          |> Enum.join(" & ")

        dynamic(
          [s, _, i, proj, prod, u],
          fragment(
            "to_tsvector('simple', concat_ws(' ', ?, coalesce(?, ''), coalesce(?, ''), coalesce(?, ''), coalesce(?, ''), coalesce(?, ''), coalesce(?, ''), coalesce(?, ''))) @@ to_tsquery('simple', ?)",
            s.title,
            i.name,
            proj.title,
            prod.title,
            s.slug,
            proj.slug,
            prod.slug,
            u.name,
            ^search_term
          )
        )
      end

    # filters
    filter_by_status =
      if options.filter_status,
        do: dynamic([s, _], s.status == ^options.filter_status),
        else: true

    filter_by_type =
      if options.filter_type do
        is_open = options.filter_type == :open
        dynamic([s, _], s.open_and_free == ^is_open)
      else
        true
      end

    filter_by_date_active =
      if options.active_today do
        today = DateTime.utc_now()
        dynamic([s, _], s.start_date <= ^today and s.end_date >= ^today)
      else
        true
      end

    filter_by_requires_payment =
      if is_nil(options.filter_requires_payment),
        do: true,
        else: dynamic([s, _], s.requires_payment == ^options.filter_requires_payment)

    filter_by_tags =
      if is_nil(options.filter_tag_ids) or options.filter_tag_ids == [],
        do: true,
        else:
          dynamic(
            [s, _],
            fragment(
              "EXISTS (SELECT 1 FROM section_tags WHERE section_id = ? AND tag_id = ANY(?))",
              s.id,
              type(^options.filter_tag_ids, {:array, :integer})
            )
          )

    filter_by_date =
      cond do
        not is_nil(options.filter_date_from) and not is_nil(options.filter_date_to) ->
          field = options.filter_date_field || :inserted_at

          dynamic(
            [s, _],
            field(s, ^field) >= ^options.filter_date_from and
              field(s, ^field) <= ^options.filter_date_to
          )

        not is_nil(options.filter_date_from) ->
          field = options.filter_date_field || :inserted_at
          dynamic([s, _], field(s, ^field) >= ^options.filter_date_from)

        not is_nil(options.filter_date_to) ->
          field = options.filter_date_field || :inserted_at
          dynamic([s, _], field(s, ^field) <= ^options.filter_date_to)

        true ->
          true
      end

    # relationship filters
    filter_by_institution =
      if is_nil(options.institution_id),
        do: true,
        else: dynamic([s, _], s.institution_id == ^options.institution_id)

    filter_by_blueprint =
      if is_nil(options.blueprint_id),
        do: true,
        else: dynamic([s, _], s.blueprint_id == ^options.blueprint_id)

    filter_by_project =
      if is_nil(options.project_id),
        do: true,
        else: dynamic([s, _], s.base_project_id == ^options.project_id)

    instructor =
      from u in User,
        join: e in Enrollment,
        on: e.user_id == u.id,
        join: ecr in "enrollments_context_roles",
        on:
          ecr.enrollment_id == e.id and ecr.context_role_id in ^Sections.get_instructor_role_ids() and
            e.status == :enrolled,
        select: %{
          name:
            fragment(
              "array_to_string(array_agg(DISTINCT ?) FILTER (WHERE ? IS NOT NULL), ', ')",
              u.name,
              u.name
            ),
          section_id: e.section_id
        },
        group_by: [e.section_id]

    student_role_id =
      ContextRoles.get_role(:context_learner).id

    student_enrollments =
      from e in Enrollment,
        join: ecr in EnrollmentContextRole,
        on: ecr.enrollment_id == e.id,
        where: ecr.context_role_id == ^student_role_id and e.status == :enrolled,
        select: %{
          id: e.id,
          section_id: e.section_id
        }

    query =
      Section
      |> join(:left, [s], e in subquery(student_enrollments), on: s.id == e.section_id)
      |> join(:left, [s, _], i in Oli.Institutions.Institution, on: s.institution_id == i.id)
      |> join(:left, [s, _], proj in Oli.Authoring.Course.Project,
        on: s.base_project_id == proj.id
      )
      |> join(:left, [s, _], prod in Section, on: s.blueprint_id == prod.id)
      |> join(:left, [s, e], u in subquery(instructor), on: u.section_id == s.id)
      |> where([s, _], s.type == :enrollable)
      |> where(^filter_by_status)
      |> where(^filter_by_type)
      |> where(^filter_by_date_active)
      |> where(^filter_by_text)
      |> where(^filter_by_institution)
      |> where(^filter_by_blueprint)
      |> where(^filter_by_project)
      |> where(^filter_by_requires_payment)
      |> where(^filter_by_tags)
      |> where(^filter_by_date)
      |> limit(^limit)
      |> offset(^offset)
      |> preload([:institution, :base_project, :blueprint])
      |> group_by([s, _, i, proj, prod, u], [
        s.id,
        i.name,
        proj.title,
        prod.title,
        u.name,
        s.slug,
        proj.slug,
        prod.slug
      ])
      |> select_merge([_, e, i, _, _, u], %{
        enrollments_count: count(e.id),
        total_count: fragment("count(*) OVER()"),
        institution_name: i.name,
        instructor_name: u.name
      })

    # sorting
    query =
      case field do
        :enrollments_count ->
          order_by(query, [_, e], {^direction, count(e.id)})

        :institution ->
          order_by(query, [_, _, i], {^direction, i.name})

        :instructor ->
          order_by(query, [_, _, _, _, _, u], {^direction, fragment("coalesce(?, '')", u.name)})

        :requires_payment ->
          order_by(query, [s, _, _], [
            {^direction, s.requires_payment},
            {^direction, fragment("CAST(?->>'amount' AS DECIMAL)", s.amount)}
          ])

        :type ->
          order_by(query, [s, _, _], {^direction, s.open_and_free})

        :base ->
          order_by(query, [_, _, _, proj, prod], [
            {^direction, fragment("coalesce(?, ?)", prod.title, proj.title)}
          ])

        _ ->
          order_by(query, [p, _], {^direction, field(p, ^field)})
      end

    # ensure there is always a stable sort order based on id, in addition to the specified sort order
    order_by(query, [s, _], s.id)
  end

  def browse_sections(
        %Paging{} = paging,
        %Sorting{} = sorting,
        %BrowseOptions{} = options
      ) do
    browse_sections_query(paging, sorting, options)
    |> Repo.all()
  end

  @doc """
  Browse sections for CSV export without paging.

  Applies the same filters and sorting as `browse_sections/3` but removes the
  pagination limits. An optional `limit` can be provided as a safety cap.
  """
  def browse_sections_for_export(
        %Sorting{} = sorting,
        %BrowseOptions{} = options,
        limit \\ 10_000
      ) do
    browse_sections_query(%Paging{offset: 0, limit: limit}, sorting, options)
    |> Repo.all()
  end

  @doc """
  Browse course sections for a specific project (used in Project Overview page).

  Returns active, enrollable sections (not blueprints) that haven't ended yet,
  with DB-level filtering, sorting, and pagination.

  ## Options
    * `:text_search` - Filter by section title (optional)

  ## Returns
  A list of maps with section data including:
    * Section fields (id, title, slug, start_date, end_date, requires_payment, amount)
    * Creator info (creator_id, creator_name, creator_email)
    * Publication info (publication_id, edition, major, minor)
    * total_count for pagination
  """
  def browse_project_sections(
        project_id,
        %Paging{limit: limit, offset: offset},
        %Sorting{direction: direction, field: field},
        opts \\ []
      ) do
    text_search = Keyword.get(opts, :text_search, "")
    today = DateTime.utc_now()

    # Text search filter using to_tsvector/to_tsquery for GIN index utilization
    # (matches pattern in browse_sections_query)
    filter_by_text =
      if text_search == "" or is_nil(text_search) do
        true
      else
        # allow to search by prefix
        search_term =
          text_search
          |> String.split(@chars_to_replace_on_search, trim: true)
          |> Enum.map(fn x -> x <> ":*" end)
          |> Enum.join(" & ")

        dynamic(
          [s],
          fragment("to_tsvector('simple', ?) @@ to_tsquery('simple', ?)", s.title, ^search_term)
        )
      end

    # LATERAL subquery to get the first enrolled user (creator) for each section
    # Uses LIMIT 1 with parent_as reference for efficient "first row per group" query
    # (matches pattern in Oli.Delivery.Sections.get_active_sections_by_project)
    first_creator_subquery =
      from(u in User,
        join: e in Enrollment,
        on: e.user_id == u.id,
        where: e.section_id == parent_as(:section).id,
        order_by: [asc: e.inserted_at],
        limit: 1,
        select: %{
          creator_id: u.id,
          creator_name: fragment("concat_ws(' ', ?, ?)", u.given_name, u.family_name),
          creator_email: u.email
        }
      )

    # Get publication for the queried project (sections can have multiple project associations)
    publication_subquery =
      from(spp in SectionsProjectsPublications,
        join: pub in Publication,
        on: pub.id == spp.publication_id,
        where: spp.section_id == parent_as(:section).id and spp.project_id == ^project_id,
        order_by: [desc: pub.published, desc: pub.id],
        limit: 1,
        select: %{
          pub_id: pub.id,
          edition: pub.edition,
          major: pub.major,
          minor: pub.minor
        }
      )

    query =
      from(s in Section,
        as: :section,
        left_lateral_join: c in subquery(first_creator_subquery),
        on: true,
        left_lateral_join: p in subquery(publication_subquery),
        on: true,
        where: s.base_project_id == ^project_id,
        where: s.type == :enrollable,
        where: s.status == :active,
        where: not is_nil(s.end_date),
        where: s.end_date >= ^today,
        where: ^filter_by_text,
        limit: ^limit,
        offset: ^offset,
        select: %{
          id: s.id,
          title: s.title,
          slug: s.slug,
          start_date: s.start_date,
          end_date: s.end_date,
          requires_payment: s.requires_payment,
          amount: s.amount,
          creator: %{
            id: c.creator_id,
            name: c.creator_name,
            email: c.creator_email
          },
          publication: %{
            id: p.pub_id,
            edition: p.edition,
            major: p.major,
            minor: p.minor
          },
          total_count: fragment("count(*) OVER()")
        }
      )

    # Apply sorting
    query =
      case field do
        :title ->
          order_by(query, [s], {^direction, s.title})

        :start_date ->
          order_by(query, [s], {^direction, s.start_date})

        :end_date ->
          order_by(query, [s], {^direction, s.end_date})

        :requires_payment ->
          order_by(query, [s], {^direction, s.requires_payment})

        :creator ->
          order_by(query, [s, c], {^direction, fragment("coalesce(?, '')", c.creator_name)})

        :publication ->
          order_by(query, [s], {^direction, s.title})

        _ ->
          order_by(query, [s], {^direction, s.title})
      end

    # Add stable sort by id
    query = order_by(query, [s], s.id)

    Repo.all(query)
  end

  @doc """
  Extracts the total count from browse results.
  Returns 0 if the list is empty.
  """
  def determine_total([]), do: 0
  def determine_total([first | _]), do: first.total_count
end
