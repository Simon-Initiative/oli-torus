defmodule OliWeb.Products.Details.ImageUpload do
  use OliWeb, :html

  attr(:product, :any, required: true)
  attr(:updates, :any, required: true)
  attr(:changeset, :any, default: nil)
  attr(:uploads, :map, required: true)
  attr(:upload_event, :any, required: true)
  attr(:change, :any, required: true)
  attr(:cancel_upload, :any, required: true)

  @preview_contexts [
    %{id: "my-course", label: "My Course"},
    %{id: "course-picker", label: "Course Picker"},
    %{id: "student-welcome", label: "Student Welcome"}
  ]

  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    has_cover_image? =
      case assigns[:product] do
        %{cover_image: cover_image} -> present?(cover_image)
        _ -> false
      end

    assigns =
      assigns
      |> assign(:preview_contexts, @preview_contexts)
      |> assign(:has_cover_image?, has_cover_image?)

    ~H"""
    <div class="container">
      <div class="grid grid-cols-12">
        <div class="col-span-12">
          <.form
            for={@changeset}
            phx-submit={@upload_event}
            phx-change="validate_image"
            id="img-upload-form"
          >
            <section>
              <div
                id="drag-and-drop-zone"
                class="drag-and-drop-zone mb-2 py-4 w-75"
                phx-drop-target={@uploads.cover_image.ref}
              >
                <div class="grid grid-cols-12 d-flex justify-content-center">
                  <div class="col-span-12 d-flex justify-content-center">
                    <div class="form-group input-file-form-group">
                      <.live_file_input upload={@uploads.cover_image} class="img-input-file" />
                      <label class="btn btn-primary js-labelFile">
                        <i class={"#{if @uploads.cover_image.entries != [], do: "fa-check", else: "fa-upload"} icon fa"}>
                        </i>
                        <span class="js-fileName">
                          <%= if @uploads.cover_image.entries != [] and !upload_has_errors?(@uploads.cover_image) do %>
                            File choosen
                          <% else %>
                            Browse
                          <% end %>
                        </span>
                      </label>
                    </div>
                  </div>
                </div>
                <div class="grid grid-cols-12">
                  <div class="col-span-12 d-flex justify-content-center">
                    <label class="text-muted">or drag and drop here</label>
                  </div>
                </div>
              </div>
            </section>

            <section class="grid grid-cols-12 mb-2" id="img-preview">
              <%= if @uploads.cover_image.entries != [] do %>
                <%= for entry <- @uploads.cover_image.entries do %>
                  <article class="upload-entry col-span-12">
                    <%= if !entry_has_errors?(@uploads.cover_image, entry) do %>
                      <figure>
                        <.live_img_preview entry={entry} />
                        <figcaption class="text-muted"><% entry.client_name %></figcaption>
                      </figure>

                      <div class="grid grid-cols-12 d-flex">
                        <div class="col-span-8 self-center h-100">
                          <div class="progress">
                            <div
                              role="progressbar"
                              class="progress-bar w-100"
                              style={"width:#{entry.progress} !important"}
                              value={entry.progress}
                              max="100"
                              aria-valuemin="0"
                              aria-valuemax="100"
                            >
                              {entry.progress}%
                            </div>
                          </div>
                        </div>
                        <div class="col-span-4 self-center h-100">
                          <button
                            type="button"
                            class="btn btn-secondary btn-sm"
                            phx-click="cancel_upload"
                            phx-value-ref={entry.ref}
                            aria-label="cancel"
                          >
                            <i class="fa-solid fa-xmark fa-lg"></i>
                          </button>
                        </div>
                      </div>
                    <% end %>

                    <%= for err <- upload_errors(@uploads.cover_image, entry) do %>
                      <div class="alert danger">{upload_error(err)}</div>
                    <% end %>
                  </article>
                <% end %>
              <% else %>
                <%= if @has_cover_image? do %>
                  <div id="img-preview-gallery" class="col-span-12 flex flex-col gap-4">
                    <article
                      id="selected-image-preview"
                      class="overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm"
                      data-preview-context="my-course"
                    >
                      <div class="border-b border-gray-200 px-4 py-3">
                        <div class="text-sm font-semibold text-gray-900">My Course</div>
                        <div class="text-xs text-gray-500">
                          Selected preview shell for the uploaded cover image
                        </div>
                      </div>
                      <div class="flex justify-center bg-gray-50 p-4">
                        <img
                          id="current-product-img"
                          src={@product.cover_image}
                          class="max-h-80 w-full rounded-xl object-contain"
                          alt="Selected cover image preview"
                        />
                      </div>
                    </article>

                    <div
                      id="image-preview-thumbnails"
                      class="grid grid-cols-1 gap-3 md:grid-cols-3"
                      role="list"
                    >
                      <%= for context <- @preview_contexts do %>
                        <article
                          id={"image-preview-thumbnail-#{context.id}"}
                          class="image-preview-thumbnail group flex h-full flex-col overflow-hidden rounded-2xl border border-gray-200 bg-white text-left shadow-sm transition-shadow hover:shadow-lg"
                          data-preview-context={context.id}
                          role="listitem"
                        >
                          <img
                            src={@product.cover_image}
                            class="h-28 w-full object-cover"
                            alt={context.label}
                          />
                          <span class="px-3 py-2 text-sm font-medium text-gray-700">
                            {context.label}
                          </span>
                        </article>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </section>

            <button
              type="submit"
              class="btn btn-primary mt-3"
              disabled={
                !upload_has_entries?(@uploads.cover_image) or upload_has_errors?(@uploads.cover_image)
              }
            >
              Save
            </button>
          </.form>
        </div>
      </div>
    </div>

    <script type="text/javascript">
      $(document).ready(function(){
        $('#drag-and-drop-zone').bind('dragover', function(){
          $(this).addClass('on-drag');
        });
        $('#drag-and-drop-zone').bind('dragleave', function(){
          $(this).removeClass('on-drag');
        });
      });
    </script>
    """
  end

  defp upload_has_entries?(upload) do
    upload.entries != []
  end

  defp present?(value), do: not is_nil(value) and value != ""

  defp upload_has_errors?(upload) do
    Enum.any?(upload.entries, &entry_has_errors?(upload, &1))
  end

  defp entry_has_errors?(upload, entry) do
    upload_errors(upload, entry) != []
  end

  defp upload_error(:too_large), do: "Image too large, try again with a image lower than 5 MB."
  defp upload_error(:too_many_files), do: "Too many files, try again with a single file"

  defp upload_error(:not_accepted),
    do: "Unacceptable file type, try again with a .jpg .jpeg or .png file"

  defp upload_error(error), do: Phoenix.Naming.humanize(error)
end
