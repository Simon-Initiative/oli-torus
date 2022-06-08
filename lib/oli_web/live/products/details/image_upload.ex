defmodule OliWeb.Products.Details.ImageUpload do
  use Surface.Component

  alias Surface.Components.{Form, LiveFileInput}
  alias Surface.Components.Form.{
    Label,
    Submit
  }

  prop product, :any, required: true
  prop updates, :any, required: true
  prop changeset, :any, default: nil
  prop uploads, :map, required: true
  prop upload_event, :event, required: true
  prop change, :event, required: true
  prop cancel_upload, :event, required: true

  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~F"""
    <div class="container">

      <div class="row">
        <div class="col-12">
          <Form for={@changeset} submit={@upload_event} change="validate_image" opts={[id: "img-upload-form"]}>

          <section>
            <div id="drag-and-drop-zone" class="drag-and-drop-zone mb-2 py-4 w-75" phx-drop-target={@uploads.cover_image.ref}>

            <div class="row d-flex justify-content-center">
                <div class="col-6 d-flex justify-content-center">

                  <div class="form-group input-file-form-group">
                    <LiveFileInput upload={@uploads.cover_image} class="img-input-file"/>
                    <label class="btn btn-dark btn-tertiary js-labelFile">
                      <i class={"#{if @uploads.cover_image.entries != [], do: "fa-check", else: "fa-upload"} icon fa"}></i>
                      <span class="js-fileName">
                        {#if @uploads.cover_image.entries != [] and !upload_has_errors?(@uploads.cover_image)}
                          File choosen
                        {#else}
                          Browse
                        {/if}
                      </span>
                    </label>
                  </div>

                </div>
              </div>
              <div class="row">
                <div class="col-12 d-flex justify-content-center">
                  <Label class="text-muted" text="or drag and drop here"/>
                </div>
              </div>
            </div>
          </section>

            <section class="row mb-2" id="img-preview">
              {#if @uploads.cover_image.entries != []}
                {#for entry <- @uploads.cover_image.entries}
                  <article class="upload-entry col-12">
                    {#if !entry_has_errors?(@uploads.cover_image, entry)}
                      <figure>
                        { live_img_preview entry, class: "img-fluid w-75"}
                        <figcaption class="text-muted">{ entry.client_name }</figcaption>
                      </figure>

                      <div class="row d-flex">
                        <div class="col-8 align-self-center h-100">
                          <div class="progress">
                            <div role="progressbar" class="progress-bar w-100" style={"width:#{entry.progress} !important"} value={entry.progress} max="100" aria-valuemin="0" aria-valuemax="100"> { entry.progress }% </div>
                          </div>
                        </div>
                        <div class="col-4 align-self-center h-100">
                          <button class="btn btn-secondary btn-sm" phx-click="cancel_upload" phx-value-ref={entry.ref} aria-label="cancel">&times;</button>
                        </div>
                      </div>
                    {/if}

                    {#for err <- upload_errors(@uploads.cover_image, entry)}
                      <div class="alert danger">{ upload_error(err) }</div>
                    {/for}

                  </article>
                {/for}
              {#else}
                <article class="col-12">
                  <img id="current-product-img" src={@product.cover_image} class="img-fluid w-75" />
                </article>
              {/if}
            </section>

            <Submit class="btn btn-primary mt-3" label="Save" opts={ [disabled: !upload_has_entries?(@uploads.cover_image) or upload_has_errors?(@uploads.cover_image)] }/>
          </Form>
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

  defp upload_has_errors?(upload) do
    Enum.any?(upload.entries, &entry_has_errors?(upload, &1))
  end

  defp entry_has_errors?(upload, entry) do
    upload_errors(upload, entry) != []
  end

  defp upload_error(:too_large), do: "Image too large, try again with a image lower than 5 MB."
  defp upload_error(:too_many_files), do: "Too many files, try again with a single file"
  defp upload_error(:not_accepted), do: "Unacceptable file type, try again with a .jpg .jpeg or .png file"
  defp upload_error(error), do: Phoenix.Naming.humanize(error)
end
