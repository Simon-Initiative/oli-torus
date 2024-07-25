defmodule Oli.Delivery.Sections.Browse do
  import Ecto.Query, warn: false

  alias Oli.Delivery.Sections.EnrollmentContextRole
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.{Section, Enrollment, BrowseOptions}
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}

  @chars_to_replace_on_search [" ", "&", ":", ";", "(", ")", "|", "!", "'", "<", ">"]

  @doc """
    Paged, sorted, filterable queries for course sections. Joins the institution,
    the base product or project and counts the number of enrollments.
  """
  def browse_sections(
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
            "to_tsvector('simple', ? || ' ' || coalesce(?, ' ') || ' ' || ? || ' ' || coalesce(?, ' ') || ' ' || coalesce(?, ' ')) @@ to_tsquery('simple', ?)",
            s.title,
            i.name,
            proj.title,
            prod.title,
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

    instructor_role_id = ContextRoles.get_role(:context_instructor).id

    instructor =
      from u in User,
        join: e in Enrollment,
        on: e.user_id == u.id,
        join: ecr in "enrollments_context_roles",
        on:
          ecr.enrollment_id == e.id and ecr.context_role_id == ^instructor_role_id and
            e.status == :enrolled,
        select: %{
          name: fragment("array_to_string((array_agg(?)), ', ')", u.name),
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
      |> limit(^limit)
      |> offset(^offset)
      |> preload([:institution, :base_project, :blueprint])
      |> group_by([s, _, i, proj, prod, u], [s.id, i.name, proj.title, prod.title, u.name])
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
            {^direction, prod.title},
            {^direction, proj.title}
          ])

        _ ->
          order_by(query, [p, _], {^direction, field(p, ^field)})
      end

    # ensure there is always a stable sort order based on id, in addition to the specified sort order
    query = order_by(query, [s, _], s.id)

    Repo.all(query)
  end
end
