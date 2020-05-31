defmodule Oli.Qa do
  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Resources
  alias Oli.Resources.{ResourceType}
  alias Oli.Qa.{Review, UriValidator}
  alias Oli.Authoring.Course
  alias Oli.Publishing

  def review_project(project_slug) do
    delete_qa_reviews(Course.get_project_by_slug(project_slug).id)

    pedagogy_review(project_slug)
    content_review(project_slug)
    accessibility_review(project_slug)

    # see how proving-ground runs link fetch requests in parallel
    # use Task for each section, group them all and return at end
  end

  defp pedagogy_review(project_slug) do
    # helpers
    pages = Repo.all(Publishing.get_unpublished_revisions_by_type(project_slug, "page"))
    activities = Repo.all(Publishing.get_unpublished_revisions_by_type(project_slug, "activity"))
    project_id = Course.get_project_by_slug(project_slug).id

    # logic
    pages_no_attached_objectives(pages, project_id)
    activities_no_attached_objectives(activities, project_id)
    pages_no_activities(pages, project_id)
  end

  defp content_review(project_slug) do
    broken_uris(project_slug)
  end

  defp accessibility_review(project_slug) do
    missing_alt_text(project_slug)
    nondescriptive_link_text(project_slug)
  end

  defp missing_alt_text(project_slug) do
    for element <- elements_of_type(project_slug, [ "img", "youtube" ]) do
      if !Map.has_key?(element.content, "alt")
      do create_qa_review(%{
        project_id: element.project_id,
        revision_id: element.id,
        type: "accessibility",
        subtype: "missing alt text",
        content: element.content
      })
      end
    end
  end

  defp nondescriptive_link_text(project_slug) do
    for element <- elements_of_type(project_slug, ["a"]) do
      # match with ["link", "click", "click here", "more", empty, single word, only images, etc]
      # link_text = ?? How to get raw link text
      if false
      do create_qa_review(%{
        project_id: element.project_id,
        revision_id: element.id,
        type: "accessibility",
        subtype: "nondescriptive link text",
        content: element.content
      })
      end
    end
  end

  defp broken_uris(project_slug) do
    for element <- UriValidator.validate_uris(elements_of_type(project_slug, ["a", "img"])) do
      create_qa_review(%{
        project_id: element.project_id,
        revision_id: element.id,
        type: "content",
        subtype: "broken remote resource",
        content: element.content
      })
    end
  end

  defp pages_no_attached_objectives(pages, project_id) do
    pages
    |> Enum.filter(& Enum.empty?(&1.objectives["attached"]))
    |> Enum.each(& create_qa_review(%{
      project_id: project_id,
      revision_id: &1.id,
      type: "pedagogy",
      subtype: "no attached objectives"
    }))
  end

  defp activities_no_attached_objectives(activities, project_id) do
    activities
    |> Enum.filter(& &1.objectives == %{})
    |> Enum.each(& create_qa_review(%{
      project_id: project_id,
      revision_id: &1.id,
      type: "pedagogy",
      subtype: "no attached objectives"
    }))
  end

  defp pages_no_activities(pages, project_id) do
    pages
    |> Enum.filter(& Enum.empty?(Resources.activity_references(&1)))
    |> Enum.each(& create_qa_review(%{
      project_id: project_id,
      revision_id: &1.id,
      type: "pedagogy",
      subtype: "no practice opportunities"
    }))
  end

  defp elements_of_type(project_slug, items) do
    publication_id = Publishing.get_unpublished_publication_by_slug!(project_slug).id
    project_id = Course.get_project_by_slug(project_slug).id
    page_id = ResourceType.get_id_by_type("page")
    activity_id = ResourceType.get_id_by_type("activity")

    item_types = items
    |> Enum.map(& ~s|@.type == "#{&1}"|)
    |> Enum.join(" || ")

    IO.inspect(item_types, label: "item types")

    sql =
      """
      select
        rev.id,
        rev.title,
        jsonb_path_query(content, '$.** ? (#{item_types})')
      from published_resources as mapping
      join revisions as rev
      on mapping.revision_id = rev.id
      where mapping.publication_id = #{publication_id}
        and (rev.resource_type_id = #{page_id}
          or rev.resource_type_id = #{activity_id})
        and rev.deleted is false
      """

    {:ok, %{rows: results }} = Ecto.Adapters.SQL.query(Oli.Repo, sql, [])

    results
    |> Enum.take_every(2)
    |> Enum.map(& %{
      project_id: project_id,
      id: Enum.at(&1, 0),
      content: Enum.at(&1, 2)
    })
  end

  # Creates a map of activity slugs to the containing page revision slugs
  def activity_to_page_slug_map(project_slug) do
    Repo.all(Publishing.get_unpublished_revisions_by_type(project_slug, "page"))
    |> Enum.reduce(%{}, fn page, acc ->
      Resources.activity_references(page)
      |> Enum.reduce(acc,
        fn activity_resource_id, acc ->
          activity_revision_slug = Oli.Publishing.AuthoringResolver.from_resource_id(project_slug, activity_resource_id).slug
          Map.update(acc, activity_revision_slug, [page.slug], fn page_slugs -> [ page.slug | page_slugs ] end)
        end)
    end)
  end

  def dismiss_warning(warning_id) do
    get_qa_review!(warning_id)
    |> update_qa_review(%{
      is_dismissed: true
    })
  end







  # Transaction logic

  def get_qa_review!(id), do: Repo.get!(Review, id)

  def list_qa_reviews(project_id) do
    Repo.all(
      from warning in Review,
      where: warning.project_id == ^project_id
        and warning.is_dismissed == false,
      preload: [revision: :resource_type])
  end

  @doc """
  Creates a qa_review.
  ## Examples
      iex> create_qa_review(%{field: value})
      {:ok, %QaReview{}}
      iex> create_qa_review(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_qa_review(attrs \\ %{}) do
    %Review{}
    |> Review.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a qa_review.
  ## Examples
      iex> update_qa_review(qa_review, %{field: new_value})
      {:ok, %QaReview{}}
      iex> update_qa_review(qa_review, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_qa_review(%Review{} = qa_review, attrs) do
    qa_review
    |> Review.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking qa_review changes.
  ## Examples
      iex> change_qa_review(qa_review)
      %Ecto.Changeset{source: %QaReview{}}
  """
  def change_qa_review(%Review{} = qa_review) do
    Review.changeset(qa_review, %{})
  end

  @doc """
  Deletes a qa_review.
  ## Examples
      iex> delete_qa_review(qa_review)
      {:ok, %QaReview{}}
      iex> delete_qa_review(qa_review)
      {:error, %Ecto.Changeset{}}
  """
  def delete_qa_review(%Review{} = qa_review) do
    Repo.delete(qa_review)
  end

  def delete_qa_reviews(project_id) do
    Repo.delete_all(from warning in Review,
      where: warning.project_id == ^project_id)
  end

end
