defmodule OliWeb.Workspaces.CourseAuthor.Products.DetailsLive do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  alias Oli.{Accounts, Publishing, Repo, Tags}
  alias Oli.Authoring.Course
  alias Oli.Delivery.Paywall
  alias Oli.Delivery.Sections
  alias Oli.Delivery.TemplatePreview
  alias Oli.Delivery.Sections.{Blueprint, Section}
  alias Oli.Inventories
  alias OliWeb.Live.Components.Sections.SectionDefaultsHelpers
  alias Oli.Utils.S3Storage
  alias OliWeb.Common.Confirm
  alias OliWeb.Live.Components.Sections.AiAssistantComponent
  alias OliWeb.Live.Components.Sections.CourseDiscussionsComponent
  alias OliWeb.Live.Components.Sections.NotesComponent
  alias OliWeb.Components.Common
  alias OliWeb.Products.Details.Actions
  alias OliWeb.Products.Details.Content
  alias OliWeb.Products.Details.Edit
  alias OliWeb.Products.Details.ImageUpload
  alias OliWeb.Products.Payments.Discounts.ProductsIndexView
  alias OliWeb.Products.ProductsToTransferCodes
  alias OliWeb.Projects.RequiredSurvey
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount
  alias OliWeb.Sections.PaywallSettings

  require Logger

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount {OliWeb.UserAuth, :mount_current_user}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  @preview_fallback_timeout_ms 10_000

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

        component_data = SectionDefaultsHelpers.load_component_data(product)

        {:ok,
         assign(
           socket,
           Map.merge(component_data, %{
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
             preview_launching?: false,
             preview_url: nil,
             base_project: base_project,
             resource_slug: project.slug,
             resource_title: project.title,
             active_workspace: :course_author,
             active_view: :products
           })
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
      <div class="grid grid-cols-12 gap-x-[14px] py-5 border-b">
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
              manage_discounts_path={
                Routes.live_path(OliWeb.Endpoint, ProductsIndexView, @product.slug)
              }
            />
          </.form>
        </div>
      </div>
      <div class="grid grid-cols-12 gap-x-[14px] py-5 border-b">
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
            ctx={@ctx}
          />
        </div>
      </div>

      <div class="grid grid-cols-12 gap-x-[14px] py-5 border-b">
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
            source_materials_url={
              ~p"/workspaces/course_author/#{@project.slug}/products/#{@product.slug}/source_materials"
            }
            customize_url={
              ~p"/workspaces/course_author/#{@project.slug}/products/#{@product.slug}/remix"
            }
            edit_url={~p"/workspaces/course_author/#{@project.slug}/products/#{@product.slug}/edit"}
            schedule_url={
              ~p"/workspaces/course_author/#{@project.slug}/products/#{@product.slug}/schedule"
            }
          />
        </div>
      </div>

      <div class="grid grid-cols-12 gap-x-[14px] py-5 border-b">
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
            <.action_link
              navigate={
                ~p"/workspaces/course_author/#{@project.slug}/products/#{@product.slug}/certificate_settings"
              }
              label="Manage certificate settings"
            />
          </div>
        </div>
      </div>

      <div class="grid grid-cols-12 gap-x-[14px] py-5 border-b">
        <div class="md:col-span-4">
          <h4>AI Assistant</h4>
          <div class="text-muted">
            Configure AI Assistant defaults for course sections created from this template.
          </div>
        </div>
        <div class="md:col-span-8">
          <.live_component
            module={AiAssistantComponent}
            id={"ai-assistant-#{@product.id}"}
            section={@product}
          />
        </div>
      </div>

      <div class="grid grid-cols-12 gap-x-[14px] py-5 border-b">
        <div class="md:col-span-4">
          <h4>Notes</h4>
          <div class="text-muted">
            Enable students to annotate content for saving and sharing within the class community.
          </div>
        </div>
        <div class="md:col-span-8">
          <.live_component
            module={NotesComponent}
            id={"notes-#{@product.id}"}
            section={@product}
            collab_space_pages_count={@collab_space_pages_count}
            pages_count={@pages_count}
          />
        </div>
      </div>

      <div class="grid grid-cols-12 gap-x-[14px] py-5 border-b">
        <div class="md:col-span-4">
          <h4>Course Discussions</h4>
          <div class="text-muted">
            Give students a course discussion board.
          </div>
        </div>
        <div class="md:col-span-8">
          <.live_component
            module={CourseDiscussionsComponent}
            id={"discussions-#{@product.id}"}
            section={@product}
            collab_space_config={@root_collab_space_config}
            root_section_resource={@root_section_resource}
          />
        </div>
      </div>

      <div class="grid grid-cols-12 gap-x-[14px] py-5 border-b">
        <div class="md:col-span-4">
          <h4>Required Survey</h4>
          <div class="max-w-[30rem] text-muted">
            Show a required survey to students who access the course for the first time.
          </div>
        </div>
        <div class="md:col-span-8">
          <%= if @show_required_section_config do %>
            <.live_component
              module={RequiredSurvey}
              project={@product}
              enabled={@product.required_survey_resource_id}
              is_section={true}
              id="workspace-required-survey"
            />
          <% else %>
            <div class="flex items-center">
              <p class="m-0 text-gray-500">
                The base project does not have a survey configured. Please contact the project author to add one.
              </p>
            </div>
          <% end %>
        </div>
      </div>

      <div class="grid grid-cols-12 gap-x-[14px] py-5">
        <div class="md:col-span-4">
          <h4>Actions</h4>
        </div>
        <div class="md:col-span-8">
          <Actions.render
            product={@product}
            is_admin={@is_admin}
            base_project={@base_project}
            has_payment_codes={Paywall.has_payment_codes?(@product.id)}
            preview_launching?={@preview_launching?}
            preview_url={@preview_url}
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

  def handle_event("template_preview", _, %{assigns: %{preview_launching?: true}} = socket) do
    {:noreply, socket}
  end

  def handle_event("template_preview", _, socket) do
    socket =
      socket
      |> clear_flash()
      |> assign(preview_launching?: true, preview_url: nil)

    case Mount.for(socket.assigns.product.slug, socket) do
      {:error, _} ->
        {:noreply,
         socket
         |> assign(preview_launching?: false)
         |> put_flash(:error, "You are not allowed to preview this template")}

      _ ->
        case TemplatePreview.prepare_launch(
               socket.assigns.product,
               Map.get(socket.assigns, :current_user),
               socket.assigns.current_author
             ) do
          {:ok, %{section_slug: section_slug, launch_identity: launch_identity}} ->
            preview_url = preview_launch_url(socket, section_slug, launch_identity)

            Process.send_after(
              self(),
              {:clear_preview_url, preview_url},
              @preview_fallback_timeout_ms
            )

            {:noreply,
             socket
             |> assign(preview_launching?: false, preview_url: preview_url)
             |> push_event("template-preview-open", %{url: preview_url})}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(preview_launching?: false)
             |> put_flash(:error, preview_error_message(reason))}
        end
    end
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

  # Generic flash handler for child LiveComponents
  def handle_info({:flash, level, message}, socket) do
    {:noreply, put_flash(socket, level, message)}
  end

  def handle_info(
        {:clear_preview_url, preview_url},
        %{assigns: %{preview_url: preview_url}} = socket
      ) do
    {:noreply, assign(socket, preview_url: nil)}
  end

  def handle_info({:clear_preview_url, _preview_url}, socket) do
    {:noreply, socket}
  end

  # Component sync handlers — delegated to shared helpers
  def handle_info({:section_updated, %Section{} = updated}, socket),
    do: {:noreply, SectionDefaultsHelpers.handle_section_updated(socket, :product, updated)}

  def handle_info({:notes_count_updated, count}, socket),
    do: {:noreply, SectionDefaultsHelpers.handle_notes_count_updated(socket, count)}

  def handle_info({:collab_space_config_updated, config, root_sr}, socket),
    do:
      {:noreply,
       SectionDefaultsHelpers.handle_collab_space_config_updated(socket, config, root_sr)}

  defp ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    ext
  end

  defp decode_welcome_title(%{"welcome_title" => wt} = project_params) when wt in [nil, ""],
    do: project_params

  defp decode_welcome_title(project_params) do
    Map.update(project_params, "welcome_title", nil, &Poison.decode!(&1))
  end

  defp preview_error_message(:missing_delivery_identity) do
    "Preview requires an available delivery identity"
  end

  defp preview_error_message(:section_unavailable) do
    "Preview is unavailable for this template"
  end

  defp preview_error_message(:unauthorized) do
    "You are not allowed to preview this template"
  end

  defp preview_error_message(_reason) do
    "Template preview could not be prepared"
  end

  defp preview_launch_url(_socket, section_slug, :current_user), do: ~p"/sections/#{section_slug}"

  defp preview_launch_url(socket, _section_slug, :hidden_instructor) do
    ~p"/authoring/products/#{socket.assigns.product.slug}/preview_launch"
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
