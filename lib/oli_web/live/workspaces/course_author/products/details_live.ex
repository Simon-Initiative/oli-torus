defmodule OliWeb.Workspaces.CourseAuthor.Products.DetailsLive do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  alias Oli.{Accounts, Publishing, Repo, Tags}
  alias Oli.Authoring.Course
  alias Oli.Delivery.Paywall
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Delivery.Sections.Section
  alias Oli.Inventories
  alias Oli.Utils.S3Storage
  alias OliWeb.Common.Confirm
  alias OliWeb.Components.Common
  alias OliWeb.Products.Details.Actions
  alias OliWeb.Products.Details.Content
  alias OliWeb.Products.Details.Edit
  alias OliWeb.Products.Details.ImageUpload
  alias OliWeb.Products.ProductsToTransferCodes
  alias OliWeb.Sections.Mount
  alias OliWeb.Sections.PaywallSettings

  require Logger

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def mount(%{"product_id" => product_slug}, _session, socket) do
    case Mount.for(product_slug, socket) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {_, _, product} ->
        author = socket.assigns.current_author
        base_project = Course.get_project!(product.base_project_id)
        publishers = Inventories.list_publishers()
        is_admin = Accounts.at_least_content_admin?(author)

        product =
          if is_admin, do: Repo.preload(product, communities: :institutions), else: product

        tags = Tags.get_section_tags(product)

        access_institutions =
          if is_admin, do: Publishing.get_institutions_with_access(product), else: []

        changeset = Section.changeset(product, %{})
        project = socket.assigns.project

        latest_publications =
          Sections.check_for_available_publication_updates(product)

        {:ok,
         assign(socket,
           publishers: publishers,
           updates: latest_publications,
           author: author,
           product: product,
           is_admin: is_admin,
           tags: tags,
           access_institutions: access_institutions,
           changeset: changeset,
           title: "Edit Template",
           show_confirm: false,
           base_project: base_project,
           resource_slug: project.slug,
           resource_title: project.title,
           active_workspace: :course_author,
           active_view: :products
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
    ~H"""
    <h2 id="header_id" class="pb-2">Template Overview</h2>
    {render_modal(assigns)}
    <div class="overview container">
      <div class="grid grid-cols-12 py-5 border-b">
        <div class="col-span-12 md:col-span-4">
          <h4>Details</h4>
          <div class="text-muted">
            The template title and description will be shown
            to instructors when they create their course section.
          </div>
        </div>
        <div class="col-span-12 md:col-span-8">
          <Edit.render
            product={@product}
            project_slug={@base_project.slug}
            changeset={@changeset}
            publishers={@publishers}
            is_admin={@is_admin}
            ctx={@ctx}
            tags={@tags}
            author={@author}
          />
          <div :if={@is_admin} id="communities-section" class="form-label-group mb-3">
            <Common.label class="control-label">Communities</Common.label>
            <p class="text-secondary">
              <Common.comma_separated_links items={
                Enum.map(@product.communities, fn c ->
                  %{name: c.name, href: ~p"/authoring/communities/#{c.id}"}
                end)
              } />
            </p>
          </div>
          <div :if={@is_admin} id="institutions-section" class="form-label-group mb-3">
            <Common.label class="control-label">Institutions</Common.label>
            <p class="text-secondary">
              <Common.comma_separated_links items={
                Enum.map(@access_institutions, fn i ->
                  %{name: i.name, href: ~p"/admin/institutions/#{i.id}"}
                end)
              } />
            </p>
          </div>
        </div>
      </div>
      <div class="grid grid-cols-12 py-5 border-b dark:border-gray-700">
        <div class="col-span-12 md:col-span-4 mr-4">
          <h4>Paywall Settings</h4>
          <div class="text-muted">
            For information regarding paywall settings,
            <.tech_support_link
              id="tech_support_paywall_settings"
              class="text-Text-text-button hover:text-Text-text-button-hover hover:underline font-semibold cursor-pointer"
            >
              contact our support team.
            </.tech_support_link>
          </div>
        </div>
        <div class="col-span-12 md:col-span-8">
          <.form
            for={@changeset}
            as={:section}
            phx-change="validate"
            phx-submit="save"
            id="paywall-settings-form"
          >
            <PaywallSettings.render
              form={to_form(@changeset)}
              disabled={!@is_admin}
              show_group={false}
            />
          </.form>
        </div>
      </div>
      <div class="grid grid-cols-12 py-5 border-b">
        <div class="md:col-span-4">
          <h4>Content</h4>
          <div class="text-muted">
            Manage and customize the presentation of content in this template.
          </div>
        </div>
        <div class="md:col-span-8">
          <Content.render
            product={@product}
            changeset={to_form(@changeset)}
            save="save"
            updates={@updates}
          />
        </div>
      </div>

      <div class="grid grid-cols-12 py-5 border-b">
        <div class="md:col-span-4">
          <h4>Cover Image</h4>
          <div class="text-muted">
            Manage the cover image for this template. Max file size is 5 MB.
          </div>
        </div>
        <div class="md:col-span-8">
          <ImageUpload.render
            product={@product}
            uploads={@uploads}
            changeset={to_form(@changeset)}
            upload_event="update_image"
            change="change"
            cancel_upload="cancel_upload"
            updates={@updates}
          />
        </div>
      </div>

      <div class="grid grid-cols-12 py-5 border-b">
        <div class="md:col-span-4">
          <h4>Certificate Settings</h4>
          <div class="max-w-[30rem] text-muted">
            Design and deliver digital credentials to students that complete this course.
          </div>
        </div>
        <div class="flex flex-col md:col-span-8 gap-2">
          <div>
            This template <b>does {unless @product.certificate_enabled, do: "not"}</b>
            currently produce a certificate.
          </div>
          <div>
            <a href={
              ~p"/workspaces/course_author/#{@project.slug}/products/#{@product.slug}/certificate_settings"
            }>
              Manage Certificate Settings
            </a>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-12 py-5">
        <div class="md:col-span-4">
          <h4>Actions</h4>
        </div>
        <div class="md:col-span-8">
          <Actions.render
            product={@product}
            is_admin={@is_admin}
            base_project={@base_project}
            has_payment_codes={Paywall.has_payment_codes?(@product.id)}
            usage_path={
              ~p"/workspaces/course_author/#{@project.slug}/products/#{@product.slug}/usage"
            }
          />
        </div>
      </div>
      <%= if @show_confirm do %>
        <Confirm.render title="Confirm Duplication" id="dialog" ok="duplicate" cancel="cancel_modal">
          Are you sure that you wish to duplicate this template?
        </Confirm.render>
      <% end %>
    </div>
    """
  end

  def handle_event("validate", %{"section" => params}, socket) do
    changeset =
      socket.assigns.product
      |> Sections.change_section(filter_paywall_params(params, socket.assigns.is_admin))

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("request_duplicate", _, socket) do
    {:noreply, assign(socket, show_confirm: true)}
  end

  def handle_event("cancel_modal", _, socket) do
    {:noreply, assign(socket, show_confirm: false)}
  end

  def handle_event("_bsmodal.unmount", _, socket) do
    {:noreply, assign(socket, show_confirm: false)}
  end

  def handle_event("duplicate", _, socket) do
    case Blueprint.duplicate(socket.assigns.product) do
      {:ok, duplicate} ->
        {:noreply,
         redirect(socket,
           to:
             ~p"/workspaces/course_author/#{socket.assigns.base_project}/products/#{duplicate.slug}"
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not duplicate template")}
    end
  end

  def handle_event("save", %{"section" => params}, socket) do
    socket = clear_flash(socket)

    params =
      params
      |> filter_paywall_params(socket.assigns.is_admin)
      |> decode_welcome_title()

    case Sections.update_section(socket.assigns.product, params) do
      {:ok, section} ->
        socket = put_flash(socket, :info, "Template changes saved")

        {:noreply, assign(socket, product: section, changeset: Section.changeset(section, %{}))}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket = put_flash(socket, :error, "Couldn't update template title")
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

        S3Storage.upload_file(bucket_name, upload_path, temp_file_path)
      end)

    with uploaded_path <- Enum.at(uploaded_files, 0),
         {:ok, section} <-
           Sections.update_section(socket.assigns.product, %{cover_image: uploaded_path}) do
      socket = put_flash(socket, :info, "Template changes saved")
      {:noreply, assign(socket, product: section, changeset: Section.changeset(section, %{}))}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        socket = put_flash(socket, :info, "Couldn't update template image")
        {:noreply, assign(socket, changeset: changeset)}

      {:error, payload} ->
        Logger.error("Error uploading product image to S3: #{inspect(payload)}")
        socket = put_flash(socket, :info, "Couldn't update template image")
        {:noreply, socket}
    end
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :cover_image, ref)}
  end

  def handle_event("show_products_to_transfer", _, socket) do
    product_id = socket.assigns.product.id
    base_project_id = socket.assigns.base_project.id

    sections = Sections.get_sections_by(base_project_id: base_project_id, type: :blueprint)

    products_to_transfer = Enum.filter(sections, &(&1.id != product_id))

    modal_assigns = %{
      id: "products_to_transfer_modal",
      products_to_transfer: products_to_transfer,
      changeset: socket.assigns.changeset
    }

    modal = fn assigns ->
      ~H"""
      <ProductsToTransferCodes.render {@modal_assigns} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event("submit_transfer_payment_codes", %{"product_id" => product_id}, socket) do
    socket = clear_flash(socket)

    socket =
      case Paywall.transfer_payment_codes(socket.assigns.product.id, product_id) do
        {0, _nil} ->
          put_flash(socket, :error, "Could not transfer payment codes")

        {_count, _} ->
          socket = put_flash(socket, :info, "Payment codes transferred successfully")

          redirect(socket,
            to: ~p"/authoring/products/#{socket.assigns.product.slug}"
          )
      end

    {:noreply, hide_modal(socket, modal_assigns: nil)}
  end

  def handle_event("welcome_title_change", %{"values" => welcome_title}, socket) do
    changeset =
      Ecto.Changeset.put_change(socket.assigns.changeset, :welcome_title, %{
        "type" => "p",
        "children" => welcome_title
      })

    {:noreply, assign(socket, changeset: changeset)}
  end

  defp ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    ext
  end

  defp decode_welcome_title(%{"welcome_title" => wt} = project_params) when wt in [nil, ""],
    do: project_params

  defp decode_welcome_title(project_params) do
    Map.update(project_params, "welcome_title", nil, &Poison.decode!(&1))
  end

  defp filter_paywall_params(params, true), do: params

  defp filter_paywall_params(params, false) do
    Map.drop(params, [
      "requires_payment",
      "amount",
      "payment_options",
      "pay_by_institution",
      "has_grace_period",
      "grace_period_days",
      "grace_period_strategy"
    ])
  end
end
