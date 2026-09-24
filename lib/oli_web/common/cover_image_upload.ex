defmodule OliWeb.Common.CoverImageUpload do
  @moduledoc """
  Shared cover-image upload flow for LiveViews that let an author or instructor replace
  a course section, template, or product's `cover_image` via a staged `:cover_image`
  upload (all three are the same `Section` schema).

  Handles the `consume_uploaded_entries/3` -> S3 upload -> `Sections.update_section/2`
  pipeline. The caller owns flashing a message and re-assigning the socket, so this
  module has no opinion on wording or which assign key the result is stored under.
  """

  import Phoenix.LiveView, only: [consume_uploaded_entries: 3]

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Utils.S3Storage

  @doc """
  Uploads the staged `:cover_image` entry (if any) for `target` to
  `"sections/\#{target.slug}/<uuid>.<ext>"` in `bucket_name`, then persists the
  resulting URL on `target`'s `cover_image` field.

  Returns `{:ok, updated_section}`, `{:error, %Ecto.Changeset{}}` on a validation
  failure, or `{:error, term()}` on an S3 upload failure (the caller is expected to
  log this case, since the failure reason shape comes from the S3 client).
  """
  @spec upload(Phoenix.LiveView.Socket.t(), String.t(), Section.t()) ::
          {:ok, Section.t()} | {:error, Ecto.Changeset.t() | term()}
  def upload(socket, bucket_name, %Section{} = target) do
    [upload_result] =
      consume_uploaded_entries(socket, :cover_image, fn meta, entry ->
        upload_path = "sections/#{target.slug}/#{entry.uuid}.#{ext(entry)}"

        {:ok, S3Storage.upload_file(bucket_name, upload_path, meta.path)}
      end)

    with {:ok, uploaded_path} <- upload_result do
      Sections.update_section(target, %{cover_image: uploaded_path})
    end
  end

  defp ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    ext
  end
end
