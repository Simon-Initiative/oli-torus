defmodule OliWeb.Products.DetailsView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Repo
  alias OliWeb.Common.Breadcrumb
  alias Oli.Accounts.Author
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Branding
  alias Oli.Inventories
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Confirm
  alias OliWeb.Sections.Mount
  alias OliWeb.Products.Details.{Actions, Edit, Content, ImageUpload}
  alias Oli.Utils.S3Storage

  require Logger

  data breadcrumbs, :any, default: [Breadcrumb.new(%{full_title: "Product Overview"})]
  data product, :any, default: nil
  data show_confirm, :boolean, default: false
  prop author, :any
  prop is_admin, :boolean

  def set_breadcrumbs(section),
    do: [
      Breadcrumb.new(%{
        full_title: section.title,
        link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
      })
    ]

  def mount(
        %{"product_id" => product_slug},
        %{"current_author_id" => author_id} = session,
        socket
      ) do
    case Mount.for(product_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {_, _, product} ->
        author = Repo.get(Author, author_id)

        available_brands =
          Branding.list_brands()
          |> Enum.map(fn brand -> {brand.name, brand.id} end)

        publishers = Inventories.list_publishers()

        {:ok,
         assign(socket,
           available_brands: available_brands,
           publishers: publishers,
           updates: Sections.check_for_available_publication_updates(product),
           author: author,
           product: product,
           is_admin: Oli.Accounts.is_admin?(author),
           changeset: Section.changeset(product, %{}),
           title: "Edit Product"
         )
         |> Phoenix.LiveView.allow_upload(:cover_image,
           accept: ~w(.jpg .jpeg .png),
           max_entries: 1,
           auto_upload: true,
           max_file_size: 5_000_000
         )}
    end
  end

  def render(assigns) do
    ~F"""
    <div class="overview container">
      <div class="grid grid-cols-12 py-5 border-b">
        <div class="md:col-span-4">
          <h4>Details</h4>
          <div class="text-muted">
            The Product title and description will be shown
            to instructors when they create their course section.
          </div>
        </div>
        <div class="md:col-span-8">
          <Edit product={@product} changeset={@changeset} available_brands={@available_brands} publishers={@publishers} is_admin={@is_admin}/>
        </div>
      </div>
      <div class="grid grid-cols-12 py-5 border-b">
        <div class="md:col-span-4">
          <h4>Content</h4>
          <div class="text-muted">
            Manage and customize the presentation of content in this product.
          </div>
        </div>
        <div class="md:col-span-8">
          <Content product={@product} changeset={@changeset} save="save" updates={@updates}/>
        </div>
      </div>

      <div class="grid grid-cols-12 py-5 border-b">
        <div class="md:col-span-4">
          <h4>Cover Image</h4>
          <div class="text-muted">
            Manage the cover image for this product. Max file size is 5 MB.
          </div>
        </div>
        <div class="md:col-span-8">
          <ImageUpload product={@product} uploads={@uploads} changeset={@changeset} upload_event="update_image" change="change" cancel_upload="cancel_upload" updates={@updates}/>
        </div>
      </div>

      <div class="grid grid-cols-12 py-5">
        <div class="md:col-span-4">
          <h4>Actions</h4>
        </div>
        <div class="md:col-span-8">
          <Actions product={@product} is_admin={@is_admin}/>
        </div>
      </div>
      {#if @show_confirm}
        <Confirm title="Confirm Duplication" id="dialog" ok="duplicate" cancel="cancel_modal">
          Are you sure that you wish to duplicate this product?
        </Confirm>
      {/if}
    </div>
    """
  end

  def handle_event("validate", %{"section" => params}, socket) do
    changeset =
      socket.assigns.product
      |> Sections.change_section(params)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("request_duplicate", _, socket) do
    {:noreply, assign(socket, show_confirm: true)}
  end

  def handle_event("cancel_modal", _, socket) do
    {:noreply, socket}
  end

  def handle_event("_bsmodal.unmount", _, socket) do
    {:noreply, assign(socket, show_confirm: false)}
  end

  def handle_event("duplicate", _, socket) do
    case Blueprint.duplicate(socket.assigns.product) do
      {:ok, duplicate} ->
        {:noreply,
         redirect(socket,
           to: Routes.live_path(socket, OliWeb.Products.DetailsView, duplicate.slug)
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not duplicate product")}
    end
  end

  def handle_event("save", %{"section" => params}, socket) do
    socket = clear_flash(socket)

    case Sections.update_section(socket.assigns.product, params) do
      {:ok, section} ->
        socket = put_flash(socket, :info, "Product changes saved")

        {:noreply, assign(socket, product: section, changeset: Section.changeset(section, %{}))}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket = put_flash(socket, :error, "Couldn't update product title")
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("validate_image", _, socket) do
    {:noreply, socket}
  end

  def handle_event("update_image", _, socket) do
    bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)

    uploaded_files =
      consume_uploaded_entries(socket, :cover_image, fn meta, entry ->
        temp_file_path = meta.path
        section_path = "sections/#{socket.assigns.product.slug}"
        image_file_name = "#{entry.uuid}.#{ext(entry)}"
        upload_path = "#{section_path}/#{image_file_name}"

        {:ok, uploaded_file} = S3Storage.upload_file(bucket_name, upload_path, temp_file_path)
        {:ok, uploaded_file}
      end)

    with uploaded_path <- Enum.at(uploaded_files, 0),
         {:ok, section} <-
           Sections.update_section(socket.assigns.product, %{cover_image: uploaded_path}) do
      socket = put_flash(socket, :info, "Product changes saved")
      {:noreply, assign(socket, product: section, changeset: Section.changeset(section, %{}))}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        socket = put_flash(socket, :info, "Couldn't update product image")
        {:noreply, assign(socket, changeset: changeset)}

      {:error, payload} ->
        Logger.error("Error uploading product image to S3: #{inspect(payload)}")
        socket = put_flash(socket, :info, "Couldn't update product image")
        {:noreply, socket}
    end
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :cover_image, ref)}
  end

  defp ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    ext
  end
end
