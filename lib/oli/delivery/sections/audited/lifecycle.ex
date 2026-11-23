defmodule Oli.Delivery.Sections.Audited.Lifecycle do
  @moduledoc false
  # Creation, archival, and deletion of sections and products (course section templates).
  #
  # Moved here:
  #   * `Oli.Delivery.create_section/1` and its private creation steps, which recorded
  #     `section_created` through `Oli.Delivery.SectionCreationAuditor` in each source branch.
  #
  # The other creation commands wrap writers that stay public because other audited commands
  # and test setup compose them: `Sections.create_section_from_source/2`,
  # `Sections.create_section_resources/2`, `Blueprint.create_blueprint/5` (which shares its
  # steps with the archive import), and `Blueprint.duplicate/3`.

  import Oli.Utils, only: [log_error: 2]

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Accounts.{Author, User}
  alias Oli.Auditing.{Command, Context}
  alias Oli.Delivery.{SectionCreation, SectionCreationRequest}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Blueprint, CopyOptions, PostProcessing, SectionCopy}
  alias Oli.Delivery.Sections.{Section, SectionSpecification}
  alias Oli.Delivery.Sections.Audited.Support
  alias Oli.Lti.{LaunchIdentity, PlatformExternalTools}
  alias Oli.Repo

  # Section creation through the course builder

  def create_section(%Context{} = context, %SectionCreationRequest{} = request) do
    with {:ok, actor} <- SectionCreation.load_actor(request.actor),
         :ok <- ensure_context_actor(context, actor),
         {:ok, section_spec} <- SectionCreation.authorize_actor(actor, request.section_spec) do
      case existing_lti_section(section_spec) do
        %Section{} = section -> {:ok, section.id, section.slug}
        nil -> create_new_section(context, request, actor, section_spec)
      end
    end
  end

  # The event names the account the request was authorized for.
  defp ensure_context_actor(%Context{actor_type: :user, user_id: id}, %User{id: id}), do: :ok

  defp ensure_context_actor(%Context{actor_type: :author, author_id: id}, %Author{id: id}),
    do: :ok

  defp ensure_context_actor(_context, _actor), do: {:error, :invalid_request}

  # Bound to the deployment that was authorized: two deployments of one registration can
  # share a context id, and each owns its own section.
  defp existing_lti_section(%SectionSpecification.Lti{
         identity: %LaunchIdentity{context_id: context_id},
         deployment: %{id: deployment_id}
       }),
       do: Sections.get_section_for_lti_deployment(context_id, deployment_id)

  defp existing_lti_section(_section_spec), do: nil

  defp create_new_section(context, %SectionCreationRequest{} = request, actor, section_spec) do
    institution = SectionSpecification.get_institution(section_spec)
    attrs = SectionCreationRequest.take_attrs(request.attrs)

    Repo.transaction(fn ->
      with {:ok, source} <- SectionCreation.resolve_source(actor, request.source, institution),
           {:ok, section, details} <-
             create_from_source(source, actor, attrs, section_spec, request.copy_options),
           :ok <- record_created(context, section, details) do
        section
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
    |> case do
      {:ok, section} ->
        {:ok, section.id, section.slug}

      {:error, reason} when is_atom(reason) ->
        {:error, reason}

      {:error, error} ->
        {_error_id, error_msg} = log_error("Failed to create new section", error)
        {:error, error_msg}
    end
  end

  defp create_from_source({:publication, publication}, actor, attrs, section_spec, _copy_options) do
    project = publication.project

    customizations =
      case project.customizations do
        nil -> nil
        labels -> Map.from_struct(labels)
      end

    section_params =
      attrs
      |> Map.merge(%{
        type: :enrollable,
        base_project_id: project.id,
        context_id: UUID.uuid4(),
        customizations: customizations,
        analytics_version: :v2,
        learning_model_version: project.learning_model_version,
        description: project.description,
        welcome_title: project.welcome_title,
        encouraging_subtitle: project.encouraging_subtitle,
        certificate: nil,
        registration_open: true,
        requires_enrollment: true
      })
      |> SectionSpecification.apply(section_spec)

    create_from_publication(actor, publication, section_params)
  end

  defp create_from_source({:product, blueprint}, actor, attrs, section_spec, _copy_options) do
    project = blueprint.base_project

    # calculate a cost, if an error, fallback to the amount in the blueprint.
    # if the amount returned is nil, it means the paywall is bypassed
    {amount, requires_payment} =
      case Oli.Delivery.Paywall.section_cost_from_product(
             blueprint,
             SectionSpecification.get_institution(section_spec)
           ) do
        {:ok, nil} -> {blueprint.amount, false}
        {:ok, amount} -> {amount, blueprint.requires_payment}
        _ -> {blueprint.amount, blueprint.requires_payment}
      end

    section_params =
      attrs
      |> Map.merge(%{
        blueprint_id: blueprint.id,
        required_survey_resource_id: project.required_survey_resource_id,
        type: :enrollable,
        context_id: UUID.uuid4(),
        analytics_version: :v2,
        learning_model_version: blueprint.learning_model_version,
        welcome_title: blueprint.welcome_title,
        encouraging_subtitle: blueprint.encouraging_subtitle,
        amount: amount,
        requires_payment: requires_payment,
        registration_open: true,
        requires_enrollment: true
      })
      |> SectionSpecification.apply(section_spec)

    create_from_product(actor, blueprint, section_params)
  end

  defp create_from_source({:section, source_section}, actor, attrs, section_spec, copy_options) do
    copy_options = copy_options || default_previous_section_copy_options()

    section_params =
      attrs
      |> Map.put(:context_id, UUID.uuid4())
      |> SectionSpecification.apply(section_spec)

    with {:ok, section} <- SectionCopy.copy(source_section, section_params, copy_options),
         {:ok, _} <- Sections.rebuild_contained_pages(section),
         {:ok, _} <- Sections.rebuild_contained_objectives(section),
         {:ok, section} <- enroll_actor(actor, section) do
      {:ok, PostProcessing.apply(section, :discussions),
       %{
         "creation_source" => "previous_section",
         "copied_groups" => CopyOptions.to_audit_list(copy_options)
       }}
    end
  end

  defp default_previous_section_copy_options do
    {:ok, options} = CopyOptions.for_previous_section(CopyOptions.groups())
    options
  end

  # Builds a course from this exact published snapshot and initializes its tool
  # selections (resource configurations chosen in external tools) before enrollment
  # and post-processing. Errors propagate to the owning creation transaction.
  defp create_from_publication(actor, publication, section_params) do
    with {:ok, section} <-
           Sections.create_section_from_source(section_params, publication.project),
         {:ok, section} <- Sections.create_section_resources(section, publication),
         {:ok, _} <-
           PlatformExternalTools.initialize_section_deep_links(section.id, publication.id),
         {:ok, _} <- Sections.rebuild_contained_pages(section),
         {:ok, _} <- Sections.rebuild_contained_objectives(section),
         {:ok, section} <- enroll_actor(actor, section) do
      {:ok, PostProcessing.apply(section, :all), %{}}
    end
  end

  defp create_from_product(actor, blueprint, section_params) do
    with {:ok, section} <- Blueprint.duplicate(blueprint, section_params),
         {:ok, _} <- Sections.rebuild_contained_pages(section),
         {:ok, _} <- Sections.rebuild_contained_objectives(section),
         {:ok, section} <- enroll_actor(actor, section) do
      {:ok, PostProcessing.apply(section, :discussions), %{"blueprint_id" => blueprint.id}}
    end
  end

  # A user actor is enrolled as instructor; an author actor enrolls nobody and reaches the
  # section by admin authorization.
  defp enroll_actor(%User{id: user_id} = user, section) do
    with :ok <- Sections.ensure_enrollment_allowed(user, section) do
      case Sections.enroll(user_id, section.id, [ContextRoles.get_role(:context_instructor)]) do
        {:ok, _enrollment} -> {:ok, section}
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  defp enroll_actor(%Author{}, section), do: {:ok, section}

  # Sections created outside the course builder

  def create_section_from_publication(%Context{} = context, publication, attrs, opts) do
    publication = Repo.preload(publication, :project)

    transaction(fn ->
      with {:ok, section} <- Sections.create_section_from_source(attrs, publication.project),
           {:ok, section} <- Sections.create_section_resources(section, publication),
           {:ok, section} <- rebuild_contained(section, Keyword.get(opts, :rebuild, false)),
           {:ok, _} <- enroll_instructor(section, Keyword.get(opts, :enroll)),
           section = post_process(section, Keyword.get(opts, :post_processing)),
           :ok <- record_created(context, section, %{}) do
        {:ok, section}
      end
    end)
  end

  def create_section_from_product(%Context{} = context, %Section{} = product, attrs, opts) do
    transaction(fn ->
      with {:ok, section} <- Blueprint.duplicate(product, attrs),
           {:ok, section} <- rebuild_contained(section, true),
           {:ok, _} <- enroll_instructor(section, Keyword.get(opts, :enroll)),
           section = post_process(section, Keyword.get(opts, :post_processing)),
           :ok <- record_created(context, section, %{"blueprint_id" => product.id}) do
        {:ok, section}
      end
    end)
  end

  defp rebuild_contained(section, false), do: {:ok, section}

  defp rebuild_contained(section, true) do
    with {:ok, _} <- Sections.rebuild_contained_pages(section),
         {:ok, _} <- Sections.rebuild_contained_objectives(section) do
      {:ok, section}
    end
  end

  defp enroll_instructor(_section, nil), do: {:ok, nil}

  defp enroll_instructor(section, %User{} = user) do
    with :ok <- Sections.ensure_enrollment_allowed(user, section) do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])
    end
  end

  defp post_process(section, nil), do: section
  defp post_process(section, steps), do: PostProcessing.apply(section, steps)

  # Products (course section templates)

  def create_product(%Context{} = context, base_project_slug, title, labels, hierarchy, attrs) do
    transaction(fn ->
      with {:ok, product} <-
             Blueprint.create_blueprint(base_project_slug, title, labels, hierarchy, attrs),
           :ok <- record_created(context, product, %{}) do
        {:ok, product}
      end
    end)
  end

  def duplicate_product(%Context{} = context, %Section{type: :blueprint} = product, attrs) do
    transaction(fn ->
      with {:ok, duplicate} <- Blueprint.duplicate(product, attrs),
           :ok <-
             record_created(context, duplicate, %{
               "creation_source" => "product_copy",
               "blueprint_id" => product.id
             }) do
        {:ok, duplicate}
      end
    end)
  end

  def duplicate_product(_context, _product, _attrs), do: {:error, :invalid_request}

  # Archival and deletion

  def archive_section(%Context{} = context, %Section{} = section),
    do: set_status(context, section, :archived)

  def delete_section(%Context{} = context, %Section{} = section),
    do: set_status(context, section, :deleted)

  # The status set by archival or deletion, recorded as `<kind>_archived` (with the status
  # before and after) or `<kind>_deleted` (which records no field changes). A section already in
  # that status records nothing.
  defp set_status(context, section, status) do
    spec =
      %{
        event_type: :"#{Support.kind(section)}_#{status}",
        policy: %{status: :value},
        proposal: fn record, _operation -> Support.lifecycle_proposal(record, status) end
      }
      |> then(fn spec ->
        case status do
          :deleted -> Map.put(spec, :changes, fn _record, _operation -> %{} end)
          :archived -> spec
        end
      end)

    result =
      Command.run(:section, fn multi ->
        Command.update(
          multi,
          :section,
          context,
          {Section, section.id},
          &Section.changeset(&1, %{status: status}),
          spec
        )
      end)

    with {:ok, updated} <- result do
      Sections.SectionCache.clear(updated.slug, [:ordered_container_labels])
      {:ok, updated}
    end
  end

  # Recording

  defp record_created(context, section, details) do
    Support.record(
      context,
      Support.lifecycle_proposal(section, :created, %{
        details:
          Map.merge(
            %{
              "section_title" => section.title,
              "type" => Atom.to_string(section.type),
              "base_project_id" => section.base_project_id
            },
            details
          )
      })
    )
  end

  # Runs `fun` in a transaction and rolls back on error. Inside a caller's transaction it joins
  # that transaction (Ecto does not use savepoints), so an error rolls back the caller's work too.
  defp transaction(fun) do
    Repo.transaction(fn ->
      case fun.() do
        {:ok, result} -> result
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end
end
