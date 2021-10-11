defmodule Oli.Delivery.Sections.Browse do
  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Sections.{Section, Enrollment, BrowseOptions}

  @doc """
  Paged, sorted, filterable queries for course sections. Joins the institution
  and counts the number of enrollments.
  """
  def browse_sections(
        %Paging{limit: limit, offset: offset},
        %Sorting{direction: direction, field: field},
        %BrowseOptions{} = options
      ) do
    filter_by_status =
      if options.show_deleted do
        true
      else
        dynamic([s, _], s.status == :active)
      end

    filter_by_text =
      if options.text_search == "" or is_nil(options.text_search) do
        true
      else
        dynamic(
          [s, _],
          ilike(s.title, ^"%#{options.text_search}%")
        )
      end

    filter_by_institution =
      if is_nil(options.institution_id) do
        true
      else
        dynamic(
          [s, _],
          s.institution_id == ^options.institution_id
        )
      end

    filter_by_blueprint =
      if is_nil(options.blueprint_id) do
        true
      else
        dynamic(
          [s, _],
          s.blueprint_id == ^options.blueprint_id
        )
      end

    filter_by_active_only =
      if !options.active_only do
        true
      else
        today = DateTime.utc_now()

        dynamic(
          [s, _],
          s.start_date <= ^today and s.end_date >= ^today
        )
      end

    query =
      Section
      |> join(:left, [s], e in Enrollment, on: s.id == e.section_id)
      |> join(:left, [s, _], i in Oli.Institutions.Institution, on: s.institution_id == i.id)
      |> where([s, _], s.type == :enrollable)
      |> where(^filter_by_status)
      |> where(^filter_by_text)
      |> where(^filter_by_institution)
      |> where(^filter_by_blueprint)
      |> where(^filter_by_active_only)
      |> limit(^limit)
      |> offset(^offset)
      |> preload(:institution)
      |> group_by([s, _, i], [s.id, i.name])
      |> select_merge([p, e, i], %{
        enrollments_count: count(e.id),
        total_count: fragment("count(*) OVER()"),
        institution_name: i.name
      })

    query =
      case field do
        :enrollments_count -> order_by(query, [_, e], {^direction, count(e.id)})
        :institution -> order_by(query, [_, _, i], {^direction, i.name})
        _ -> order_by(query, [p, _], {^direction, field(p, ^field)})
      end

    Repo.all(query)
  end
end
