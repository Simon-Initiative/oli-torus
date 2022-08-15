defmodule Oli.Resources.PageBrowse do
  import Ecto.Query, warn: false

  alias Oli.Resources.PageBrowseOptions
  alias Oli.Repo
  alias Oli.Authoring.Course.Project
  alias Oli.Resources.Revision
  alias Oli.Repo.{Paging, Sorting}

  @chars_to_replace_on_search [" ", "&", ":", ";", "(", ")", "|", "!", "'", "<", ">"]

  @doc """
    Paged, sorted, filterable queries for course sections. Joins the institution,
    the base product or project and counts the number of enrollments.
  """
  def browse_pages(
        %Project{id: project_id},
        %Paging{limit: limit, offset: offset},
        %Sorting{direction: direction, field: field},
        %PageBrowseOptions{} = options
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
          [rev, _, _, _],
          fragment(
            "to_tsvector('simple', ?) @@ to_tsquery('simple', ?)",
            rev.title,
            ^search_term
          )
        )
      end

    filter_by_graded =
      if !is_nil(options.graded),
        do: dynamic([rev, _, _, _], rev.graded == ^options.graded),
        else: true

    filter_by_deleted =
      if !is_nil(options.deleted) do
        dynamic([rev, _, _, _], rev.deleted == ^options.deleted)
      else
        true
      end

    filter_by_page_type =
      if is_nil(options.basic) do
        true
      else
        if options.basic do
          dynamic(
            [rev, _, _, _],
            fragment(
              "NOT (?->>'advancedDelivery' = true)",
              rev.content
            )
          )
        else
          dynamic(
            [rev, _, _, _],
            fragment(
              "?->>'advancedDelivery' = true",
              rev.content
            )
          )
        end
      end

    page_type_id = Oli.Resources.ResourceType.get_id_by_type("page")

    query =
      Revision
      |> join(:left, [rev], pr in Oli.Publishing.PublishedResource, on: pr.revision_id == rev.id)
      |> join(:left, [_, pr], pub in Oli.Publishing.Publication, on: pr.publication_id == pub.id)
      |> join(:left, [_, _, pub], proj in Oli.Authoring.Course.Project,
        on: pub.project_id == proj.id
      )
      |> where(
        [rev, _, pub, proj],
        proj.id == ^project_id and is_nil(pub.published) and rev.resource_type_id == ^page_type_id
      )
      |> where(^filter_by_text)
      |> where(^filter_by_graded)
      |> where(^filter_by_deleted)
      |> where(^filter_by_page_type)
      |> limit(^limit)
      |> offset(^offset)
      |> select_merge([rev, _, _, _], %{
        total_count: fragment("count(*) OVER()"),
        page_type:
          fragment(
            "case when ?->>'advancedDelivery' = 'true' then 'Advanced' else 'Regular' end",
            rev.content
          )
      })

    # sorting
    query =
      case field do
        :page_type ->
          order_by(
            query,
            [rev, _, _, _],
            {^direction,
             fragment(
               "case when ?->>'advancedDelivery' = 'true' then 'Advanced' else 'Regular' end",
               rev.content
             )}
          )

        _ ->
          order_by(query, [rev, _, _, _], {^direction, field(rev, ^field)})
      end

    Repo.all(query)
  end

  def find_parent_container(project, page_revision) do
    container_type_id = Oli.Resources.ResourceType.get_id_by_type("container")

    query =
      Revision
      |> join(:left, [rev], pr in Oli.Publishing.PublishedResource, on: pr.revision_id == rev.id)
      |> join(:left, [_, pr], pub in Oli.Publishing.Publication, on: pr.publication_id == pub.id)
      |> join(:left, [_, _, pub], proj in Oli.Authoring.Course.Project,
        on: pub.project_id == proj.id
      )
      |> where(
        [rev, _, pub, proj],
        proj.id == ^project.id and is_nil(pub.published) and
          rev.resource_type_id == ^container_type_id
      )
      |> where(
        [rev, _, _, _],
        fragment("? = ANY (?)", ^page_revision.resource_id, rev.children)
      )

    Repo.all(query)
  end
end
