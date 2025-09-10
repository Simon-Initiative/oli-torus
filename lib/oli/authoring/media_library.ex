defmodule Oli.Authoring.MediaLibrary do
  import Ecto.Query, warn: false
  alias Oli.Authoring.MediaLibrary.MediaItem
  alias Oli.Authoring.MediaLibrary.ItemOptions
  alias Oli.Authoring.Course.Project
  alias Oli.Repo
  alias ExAws.S3
  alias ExAws

  @doc """
  Returns the number of the non-deleted media items in a particular
  project's media library.

  If the project matching the supplied slug exists, the following is returned:
  `{:ok, count`} where `count` is the number of non-deleted items in the library

  If the project does not exist,
  `{:error, {:not_found}}` is returned
  """
  @spec size(String.t()) :: {:ok, number()} | {:error, {:not_found}}
  def size(project_slug) do
    case Oli.Authoring.Course.get_project_by_slug(project_slug) do
      nil ->
        {:error, {:not_found}}

      %Project{id: id} ->
        {:ok,
         MediaItem
         |> where([item], item.project_id == ^id and item.deleted == false)
         |> select([item], count(item.id))
         |> Repo.one()}
    end
  end

  @doc """
  Adds an item to the media library for a specific project slug.

  The other supplied parameters are the file name, including extension
  and the contents of the file as a bitstring.

  An example of the format of the `file_name` param: `untitled.jpg`

  Returns `{:ok, %MediaItem{}}` on success where `%MediaItem{}` is the
  meta data entry that was created.

  If the file was identified to be a duplicate via comparison of its MD5 hash
  to other items in the library in this project, `{:ok, %MediaItem{}}`
  will be returned with the existing `%MediaItem{}` entry, and not a newly
  created one.

  If another file already exists with the same name in the project
  `{:error, {:file_exists}}` is returned

  If a problem occurs in persisting the file
  `{:error, {:persistence}}` or `{:error, %Changeset{}}` is returned
  depending on whether it was a problem in persisting the file contents
  to storage or it was a problem saving file meta data

  If the project does not exist,
  `{:error, {:not_found}}` is returned
  """
  @spec add(String.t(), String.t(), any) :: {:ok, %MediaItem{}} | {:error, any}
  def add(project_slug, file_name, file_contents) do
    project = Oli.Authoring.Course.get_project_by_slug(project_slug)

    if project != nil do
      hash = :crypto.hash(:md5, file_contents) |> Base.encode16()

      # We must ensure that a file with the same content is not added again to the
      # library to prevent unecessary duplication of storage
      case check_for_duplicates(project.id, file_name, hash) do
        # Upload the file and insert the meta data
        {:no_duplicate_found, _} ->
          upload(file_name, file_contents)
          |> insert(project.id, file_name, file_contents, hash)

        {:duplicate_content, item} ->
          if item.deleted do
            restore_item(item.id)
            {:ok, item}
          else
            {:duplicate, item}
          end
      end
    else
      {:error, {:not_found}}
    end
  end

  @spec delete_media_items(String.t(), any) :: {:ok, any} | {:error, any}
  def delete_media_items(project_slug, media_ids) do
    project = Oli.Authoring.Course.get_project_by_slug(project_slug)

    if project != nil do
      case delete_items(media_ids) do
        {changes_count, nil} when is_integer(changes_count) ->
          {:ok, changes_count}

        error ->
          {:error, error}
      end
    else
      {:error, {:not_found}}
    end
  end

  def delete_items(media_ids) do
    from(m in MediaItem, where: m.id in ^media_ids)
    |> Repo.update_all(set: [deleted: true])
  end

  def restore_item(media_id) do
    from(m in MediaItem, where: m.id == ^media_id)
    |> Repo.update_all(set: [deleted: false])
  end

  @doc """
  Access the items in a project's media library with support for paging
  and filtering.

  Returns `{:ok, {[%MediaItem{}], count}}` with the list of media items matching
  the paged and filtered request.

  The `count` is designed specifically to support client-side paging logic and is the
  count of the total number of items that would match the query absent any paging. As
  an example, if a client made a paged request for the first fifty items in a media
  library containing two-hundred items this count will read `200`.
  """
  @spec items(String.t(), %ItemOptions{}) ::
          {:ok, {[%MediaItem{}], number()}} | {:error, {:not_found}}
  def items(project_slug, options) do
    base_query =
      MediaItem
      |> join(:inner, [item], assoc(item, :project), as: :project)
      |> where(^items_where(project_slug, options))

    full_query =
      base_query
      |> items_order_by(options)
      |> limit_offset(options)
      |> select([i], i)

    count_query =
      base_query
      |> select([item], count(item.id))

    case Map.get(options, :limit) do
      nil ->
        all = full_query |> Repo.all()
        {:ok, {all, length(all)}}

      _ ->
        case count_query |> Repo.one() do
          0 -> {:ok, {[], 0}}
          count -> {:ok, {full_query |> Repo.all(), count}}
        end
    end
  end

  defp limit_offset(query, %ItemOptions{limit: nil, offset: nil}),
    do: query

  defp limit_offset(query, %ItemOptions{limit: limit, offset: offset}),
    do: query |> limit(^limit) |> offset(^offset)

  defp items_order_by(query, %ItemOptions{order_field: nil}),
    do: order_by(query, [i, _], desc: i.file_name)

  defp items_order_by(query, %ItemOptions{order_field: "fileSize", order: "asc"}),
    do: order_by(query, [i, _], asc: i.file_size)

  defp items_order_by(query, %ItemOptions{order_field: "fileSize"}),
    do: order_by(query, [i, _], desc: i.file_size)

  defp items_order_by(query, %ItemOptions{order_field: "mimeType", order: "asc"}),
    do: order_by(query, [i, _], asc: i.mime_type)

  defp items_order_by(query, %ItemOptions{order_field: "mimeType"}),
    do: order_by(query, [i, _], desc: i.mime_type)

  defp items_order_by(query, %ItemOptions{order_field: "dateCreated", order: "asc"}),
    do: order_by(query, [i, _], asc: i.inserted_at)

  defp items_order_by(query, %ItemOptions{order_field: "dateCreated"}),
    do: order_by(query, [i, _], desc: i.inserted_at)

  defp items_order_by(query, %ItemOptions{order_field: "fileName", order: "asc"}),
    do: order_by(query, [i, _], asc: i.file_name)

  defp items_order_by(query, %ItemOptions{order_field: "fileName"}),
    do: order_by(query, [i, _], desc: i.file_name)

  defp items_where(slug, params) do
    Map.keys(params)
    |> Enum.map(fn k -> {k, Map.get(params, k)} end)
    |> Enum.reduce(dynamic([item, project: p], p.slug == ^slug and item.deleted == false), fn
      {:mime_filter, nil}, dynamic ->
        dynamic

      {:url_filter, nil}, dynamic ->
        dynamic

      {:search_text, nil}, dynamic ->
        dynamic

      {:mime_filter, value}, dynamic ->
        dynamic([p], ^dynamic and p.mime_type in ^value)

      {:url_filter, value}, dynamic ->
        dynamic([p], ^dynamic and p.url == ^value)

      {:search_text, value}, dynamic ->
        dynamic([p], ^dynamic and ilike(p.file_name, ^"%#{value}%"))

      {_, _}, dynamic ->
        # Not a where parameter, pass by it
        dynamic
    end)
  end

  defp check_for_duplicates(project_id, _, hash) do
    case Oli.Repo.get_by(MediaItem, project_id: project_id, md5_hash: hash) do
      nil -> {:no_duplicate_found, nil}
      item -> {:duplicate_content, item}
    end
  end

  def upload_path(file_name, contents) do
    hash = :crypto.hash(:md5, contents) |> Base.encode16()

    subdir = hash |> String.slice(0..1)

    "/media/#{subdir}/#{hash}/#{file_name}"
  end

  defp upload_file(bucket, file_name, contents) do
    mime_type = MIME.from_path(file_name)
    options = [{:acl, :public_read}, {:content_type, mime_type}]
    S3.put_object(bucket, file_name, contents, options) |> ExAws.request()
  end

  defp upload(file_name, file_contents) do
    path = upload_path(file_name, file_contents)

    bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)

    media_url = Application.fetch_env!(:oli, :media_url)

    case upload_file(bucket_name, path, file_contents) do
      {:ok, %{status_code: 200}} -> {:ok, "#{media_url}#{path}"}
      _ -> {:error, {:persistence}}
    end
  end

  defp insert({:ok, url}, project_id, file_name, file_contents, hash) do
    create_media_item(%{
      project_id: project_id,
      file_name: file_name,
      url: url,
      mime_type: MIME.from_path(file_name),
      file_size: byte_size(file_contents),
      md5_hash: hash,
      deleted: false
    })
  end

  defp insert(error, _, _, _, _), do: error

  @doc """
  Creates a media item.
  ## Examples
      iex> create_media_item(%{field: value})
      {:ok, %MediaItem{}}
      iex> create_media_item(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_media_item(attrs \\ %{}) do
    %MediaItem{}
    |> MediaItem.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a media item.
  ## Examples
      iex> update_media_item(revision, %{field: new_value})
      {:ok, %MediaItem{}}
      iex> update_media_item(revision, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_media_item(media_item, attrs) do
    MediaItem.changeset(media_item, attrs)
    |> Repo.update()
  end

  def change_media_item(%MediaItem{} = media_item, attrs \\ %{}) do
    MediaItem.changeset(media_item, attrs)
  end
end
