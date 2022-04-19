defmodule Oli.Delivery.Sections.Browse do
  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Sections.{Section, Enrollment, BrowseOptions}

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
        dynamic(
          [s, _, i, proj, prod],
          ilike(s.title, ^"%#{options.text_search}%") or
          ilike(i.name, ^"%#{options.text_search}%") or
          ilike(proj.title, ^"%#{options.text_search}%") or
          ilike(prod.title, ^"%#{options.text_search}%")
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
      if options.active_date do
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

    query =
      Section
      |> join(:left, [s], e in Enrollment, on: s.id == e.section_id)
      |> join(:left, [s, _], i in Oli.Institutions.Institution, on: s.institution_id == i.id)
      |> join(:left, [s, _], proj in Oli.Authoring.Course.Project, on: s.base_project_id == proj.id)
      |> join(:left, [s, _], prod in Section, on: s.blueprint_id == prod.id)
      |> where([s, _], s.type == :enrollable)
      |> where(^filter_by_status)
      |> where(^filter_by_type)
      |> where(^filter_by_date_active)
      |> where(^filter_by_text)
      |> where(^filter_by_institution)
      |> where(^filter_by_blueprint)
      |> limit(^limit)
      |> offset(^offset)
      |> preload([:institution, :base_project, :blueprint])
      |> group_by([s, _, i, proj, prod], [s.id, i.name, proj.title, prod.title])
      |> select_merge([p, e, i, proj], %{
        enrollments_count: count(e.id),
        total_count: fragment("count(*) OVER()"),
        institution_name: i.name
      })

    # sorting
    query =
      case field do
        :enrollments_count -> order_by(query, [_, e], {^direction, count(e.id)})
        :institution -> order_by(query, [_, _, i], {^direction, i.name})
        :requires_payment -> order_by(query, [s, _, _], {^direction, s.amount})
        :type -> order_by(query, [s, _, _], {^direction, s.open_and_free})
        :base -> order_by(query, [_, _, _, proj, prod], [{^direction, prod.title}, {^direction, proj.title}])
        _ -> order_by(query, [p, _], {^direction, field(p, ^field)})
      end

    Repo.all(query)
  end
end
