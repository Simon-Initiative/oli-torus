defmodule Oli.Resources.ActivityBrowse do
  import Ecto.Query, warn: false

  alias Oli.Resources.ActivityBrowseOptions
  alias Oli.Repo
  alias Oli.Authoring.Course.Project
  alias Oli.Resources.Revision
  alias Oli.Repo.{Paging, Sorting}

  @chars_to_replace_on_search [" ", "&", ":", ";", "(", ")", "|", "!", "'", "<", ">"]

  @doc """
    Paged, sorted, filterable queries for course sections. Joins the institution,
    the base product or project and counts the number of enrollments.
  """
  def browse_activities(
        %Project{id: project_id},
        %Paging{limit: limit, offset: offset},
        %Sorting{direction: direction, field: field},
        %ActivityBrowseOptions{} = options
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
          [rev, ar, _, _, _],
          fragment(
            "to_tsvector('simple', ?) @@ to_tsquery('simple', ?)",
            ar.petite_label,
            ^search_term
          )
        )
      end

    filter_by_deleted =
      if !is_nil(options.deleted) do
        dynamic([rev, _, _, _], rev.deleted == ^options.deleted)
      else
        true
      end

    filter_by_activity_type_id =
      if is_nil(options.activity_type_id) do
        true
      else
        dynamic([rev, _, _, _], rev.activity_type_id == ^options.activity_type_id)
      end

    activity_resource_type_id = Oli.Resources.ResourceType.id_for_activity()

    query =
      Revision
      |> join(:left, [rev], ar in Oli.Activities.ActivityRegistration,
        on: ar.id == rev.activity_type_id
      )
      |> join(:left, [rev, _ar], pr in Oli.Publishing.PublishedResource,
        on: pr.revision_id == rev.id
      )
      |> join(:left, [_, _, pr], pub in Oli.Publishing.Publications.Publication,
        on: pr.publication_id == pub.id
      )
      |> join(:left, [_, _, _, pub], proj in Oli.Authoring.Course.Project,
        on: pub.project_id == proj.id
      )
      |> where(
        [rev, _, _, pub, proj],
        proj.id == ^project_id and is_nil(pub.published) and
          rev.resource_type_id == ^activity_resource_type_id
      )
      |> where(^filter_by_text)
      |> where(^filter_by_activity_type_id)
      |> where(^filter_by_deleted)
      |> limit(^limit)
      |> offset(^offset)
      |> select_merge([rev, _, _, _], %{
        total_count: fragment("count(*) OVER()")
      })

    # sorting
    query = order_by(query, [rev, _, _, _], {^direction, field(rev, ^field)})

    Repo.all(query)
  end
end
