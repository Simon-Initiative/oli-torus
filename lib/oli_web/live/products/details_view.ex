defmodule OliWeb.Products.DetailsView do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  alias Oli.{Accounts, Branding, Inventories, Publishing, Repo, Tags}
  alias Oli.Authoring.Course
  alias Oli.Delivery.{Paywall, Sections}
  alias Oli.Delivery.Sections.{Blueprint, Section, SectionResource}
  alias Oli.Resources.Collaboration
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Utils.S3Storage
  alias OliWeb.Common.{Breadcrumb, Confirm}
  alias OliWeb.Components.{Common, Overview}
  alias OliWeb.Live.Components.Tags.TagsComponent
  alias OliWeb.Live.Components.Sections.AiAssistantComponent
  alias OliWeb.Live.Components.Sections.CourseDiscussionsComponent
  alias OliWeb.Live.Components.Sections.NotesComponent
  alias OliWeb.Products.Details.{Actions, Edit, Content, ImageUpload}
  alias OliWeb.Products.ProductsToTransferCodes
  alias OliWeb.Projects.RequiredSurvey
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount

  require Logger

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def set_breadcrumbs(section),
    do: [
      Breadcrumb.new(%{
        full_title: section.title,
        link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
      })
    ]

  def mount(
        %{"product_id" => product_slug},
        _session,
        socket
      ) do
    case Mount.for(product_slug, socket) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {_, _, product} ->
        author = socket.assigns.current_author

        product = Repo.preload(product, communities: :institutions)
        tags = Tags.get_section_tags(product)

        is_admin? = Accounts.has_admin_role?(author, :content_admin)

        base_project = Course.get_project!(product.base_project_id)

        access_institutions = Publishing.get_institutions_with_access(product)

        available_brands =
          Branding.list_brands()
          |> Enum.map(fn brand -> {brand.name, brand.id} end)

        publishers = Inventories.list_publishers()

        # Notes: load page-level collab space counts
        {collab_space_pages_count, pages_count} =
          Collaboration.count_collab_spaces_enabled_in_pages_for_section(product.slug)

        # Discussions: load root container's section_resource and collab_space_config
        root_revision = DeliveryResolver.root_container(product.slug)

        {root_section_resource, root_collab_space_config} =
          if root_revision do
            {:ok, config} =
              Collaboration.get_collab_space_config_for_page_in_section(
                root_revision.slug,
                product.slug
              )

            root_sr = Repo.get(SectionResource, product.root_section_resource_id)
            {root_sr, config}
          else
            {nil, nil}
          end

        # Required Survey: check if base project has a survey
        show_required_section_config =
          if product.required_survey_resource_id != nil or
               Sections.get_base_project_survey(product.slug) do
            true
          else
            false
          end

        {:ok,
         assign(socket,
           available_brands: available_brands,
           publishers: publishers,
           updates: Sections.check_for_available_publication_updates(product),
           author: author,
           product: product,
           tags: tags,
           is_admin: is_admin?,
           access_institutions: access_institutions,
           changeset: Section.changeset(product, %{}),
           title: "Edit Template",
           show_confirm: false,
           breadcrumbs: [Breadcrumb.new(%{full_title: "Template Overview"})],
           base_project: base_project,
           collab_space_pages_count: collab_space_pages_count,
           pages_count: pages_count,
           root_section_resource: root_section_resource,
           root_collab_space_config: root_collab_space_config,
           show_required_section_config: show_required_section_config
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
    {render_modal(assigns)}
    <div class="overview container">
      <Overview.section
        title="Details"
        description="The template title and description will be shown to instructors when they create their course section."
      >
        <Edit.render
          product={@product}
          project_slug={@base_project.slug}
          changeset={@changeset}
          available_brands={@available_brands}
          publishers={@publishers}
          is_admin={@is_admin}
          ctx={@ctx}
        />
        <div class="form-label-group mb-3 mt-3">
          <Common.label class="control-label">Tags</Common.label>
          <.live_component
            :if={@is_admin}
            module={TagsComponent}
            id={"product-tags-#{@product.id}"}
            entity_type={:section}
            entity_id={@product.id}
            current_tags={@tags}
            current_author={@author}
            variant={:form}
          />
          <TagsComponent.read_only_tags :if={!@is_admin} tags={@tags} />
        </div>
        <div id="communities-section" class="form-label-group mb-3">
          <Common.label class="control-label">Communities</Common.label>
          <p class="text-secondary">
            <Common.comma_separated_links items={
              Enum.map(@product.communities, fn c ->
                %{name: c.name, href: ~p"/authoring/communities/#{c.id}"}
              end)
            } />
          </p>
        </div>
        <div id="institutions-section" class="form-label-group mb-3">
          <Common.label class="control-label">Institutions</Common.label>
          <p class="text-secondary">
            <Common.comma_separated_links items={
              Enum.map(@access_institutions, fn i ->
                %{name: i.name, href: ~p"/admin/institutions/#{i.id}"}
              end)
            } />
          </p>
        </div>
      </Overview.section>

      <Overview.section
        title="Paywall Settings"
        description="Manage payment requirements for this template."
      >
        <p class="text-secondary">
          For information regarding paywall settings,
          <.tech_support_link
            id="tech_support_paywall_settings"
            class="text-Text-text-button hover:text-Text-text-button-hover hover:underline font-semibold cursor-pointer"
          >
            contact our support team.
          </.tech_support_link>
        </p>
      </Overview.section>

      <Overview.section
        title="Cover Image"
        description="Manage the cover image for this template. Max file size is 5 MB."
      >
        <ImageUpload.render
          product={@product}
          uploads={@uploads}
          changeset={to_form(@changeset)}
          upload_event="update_image"
          change="change"
          cancel_upload="cancel_upload"
          updates={@updates}
        />
      </Overview.section>

      <Overview.section
        title="Content"
        description="Manage and customize the presentation of content in this template."
      >
        <Content.render
          product={@product}
          changeset={to_form(@changeset)}
          save="save"
          updates={@updates}
        />
      </Overview.section>

      <Overview.section
        title="Certificate Settings"
        description="Design and deliver digital credentials to students that complete this course."
      >
        <div class="flex flex-col gap-2">
          <div>
            This template <b>does {unless @product.certificate_enabled, do: "not"}</b>
            currently produce a certificate.
          </div>
          <div>
            <a href={~p"/authoring/products/#{@product.slug}/certificate_settings"}>
              Manage Certificate Settings
            </a>
          </div>
        </div>
      </Overview.section>

      <Overview.section
        title="AI Assistant"
        description="Configure AI Assistant defaults for course sections created from this template."
      >
        <.live_component
          module={AiAssistantComponent}
          id={"ai-assistant-#{@product.id}"}
          section={@product}
        />
      </Overview.section>

      <Overview.section
        title="Notes"
        description="Enable students to annotate content for saving and sharing within the class community."
      >
        <.live_component
          module={NotesComponent}
          id={"notes-#{@product.id}"}
          section={@product}
          collab_space_pages_count={@collab_space_pages_count}
          pages_count={@pages_count}
        />
      </Overview.section>

      <Overview.section
        title="Course Discussions"
        description="Give students a course discussion board."
      >
        <.live_component
          module={CourseDiscussionsComponent}
          id={"discussions-#{@product.id}"}
          section={@product}
          collab_space_config={@root_collab_space_config}
          root_section_resource={@root_section_resource}
        />
      </Overview.section>

      <Overview.section
        title="Required Survey"
        description="Show a required survey to students who access the course for the first time."
      >
        <%= if @show_required_section_config do %>
          <.live_component
            module={RequiredSurvey}
            project={@product}
            enabled={@product.required_survey_resource_id}
            is_section={true}
            id="product-required-survey"
          />
        <% else %>
          <div class="flex items-center">
            <p class="m-0 text-gray-500">
              The base project does not have a survey configured. Please contact the project author to add one.
            </p>
          </div>
        <% end %>
      </Overview.section>

      <Overview.section
        title="Scheduling & Assessment Settings"
        description="Configure scheduling and assessment settings for this template."
      >
        <a
          href={~p"/authoring/products/#{@product.slug}/schedule"}
          class="btn btn-link"
        >
          Edit scheduling and assessment settings
        </a>
      </Overview.section>

      <Overview.section
        title="Edit Template Details"
        description="Edit template details, paywall settings, and content settings for this template."
      >
        <a
          href={~p"/authoring/products/#{@product.slug}/edit"}
          class="btn btn-link"
        >
          Edit Template Details
        </a>
      </Overview.section>

      <Overview.section
        :if={@is_admin}
        title="Feature Flags"
        description="Manage scoped feature flags for this template."
      >
        <.live_component
          module={OliWeb.Components.ScopedFeatureToggleComponent}
          id="section_scoped_features"
          scopes={[:delivery, :both]}
          source_id={@product.id}
          source_type={:section}
          source={@product}
          current_author={@author}
          title="Template Features"
        />
      </Overview.section>

      <Overview.section title="Actions" is_last={true}>
        <Actions.render
          product={@product}
          is_admin={@is_admin}
          base_project={@base_project}
          has_payment_codes={Paywall.has_payment_codes?(@product.id)}
        />
      </Overview.section>

      <Confirm.render
        :if={@show_confirm}
        title="Confirm Duplication"
        id="dialog"
        ok="duplicate"
        cancel="cancel_modal"
      >
        Are you sure that you wish to duplicate this template?
      </Confirm.render>
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
        {:noreply, put_flash(socket, :error, "Could not duplicate template")}
    end
  end

  def handle_event("save", %{"section" => params}, socket) do
    socket = clear_flash(socket)

    case Sections.update_section(socket.assigns.product, decode_welcome_title(params)) do
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

        {:ok, uploaded_file} = S3Storage.upload_file(bucket_name, upload_path, temp_file_path)
        {:ok, uploaded_file}
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
    products_to_transfer =
      Oli.Delivery.Sections.get_sections_by(
        base_project_id: socket.assigns.base_project.id,
        type: :blueprint
      )
      |> Enum.filter(fn product -> product.id != socket.assigns.product.id end)

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

    {:noreply,
     show_modal(
       socket,
       modal,
       modal_assigns: modal_assigns
     )}
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

  def handle_info({:scoped_feature_updated, feature_name, enabled, _source}, socket) do
    action = if enabled, do: "enabled", else: "disabled"
    message = "Feature '#{feature_name}' #{action} successfully"
    {:noreply, put_flash(socket, :info, message)}
  end

  def handle_info({:scoped_feature_error, feature_name, error_message}, socket) do
    message = "Failed to update feature '#{feature_name}': #{error_message}"
    {:noreply, put_flash(socket, :error, message)}
  end

  def handle_info({:scoped_feature_notice, type, message}, socket) do
    level = if type == :error, do: :error, else: :info
    {:noreply, put_flash(socket, level, message)}
  end

  # Generic flash handler for child LiveComponents
  def handle_info({:flash, level, message}, socket) do
    {:noreply, put_flash(socket, level, message)}
  end

  # Keep @product in sync when child LiveComponents update the section.
  # We merge only scalar fields from the updated section onto the existing @product
  # to preserve preloaded associations (e.g. communities) that the render function needs.
  def handle_info({:section_updated, %Oli.Delivery.Sections.Section{} = updated_section}, socket) do
    current_product = socket.assigns.product

    merged =
      Map.merge(
        Map.from_struct(current_product),
        Map.from_struct(updated_section),
        fn _key, current_val, new_val ->
          case new_val do
            %Ecto.Association.NotLoaded{} -> current_val
            _ -> new_val
          end
        end
      )

    {:noreply, assign(socket, product: struct(Oli.Delivery.Sections.Section, merged))}
  end

  # Keep parent's notes count in sync so NotesComponent doesn't get stale assigns on re-render
  def handle_info({:notes_count_updated, count}, socket) do
    {:noreply, assign(socket, collab_space_pages_count: count)}
  end

  # Keep parent's collab_space_config in sync so CourseDiscussionsComponent doesn't get stale
  # assigns on re-render (e.g. when another component triggers a parent re-render)
  def handle_info({:collab_space_config_updated, config, root_sr}, socket) do
    {:noreply,
     assign(socket,
       root_collab_space_config: config,
       root_section_resource: root_sr
     )}
  end

  defp ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    ext
  end

  defp decode_welcome_title(%{"welcome_title" => nil} = project_params), do: project_params

  defp decode_welcome_title(%{"welcome_title" => ""} = project_params),
    do: %{project_params | "welcome_title" => nil}

  defp decode_welcome_title(project_params),
    do: Map.update(project_params, "welcome_title", nil, &Poison.decode!(&1))
end
