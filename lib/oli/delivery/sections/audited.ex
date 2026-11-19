defmodule Oli.Delivery.Sections.Audited do
  @moduledoc """
  Application boundary for audited changes to sections and products (course section
  templates): their lifecycle, settings, discussion configuration, remixes, publication
  updates, and schedules.

  Each command writes its change and its audit events in one transaction, so a change is never
  committed without its events and a failed or rolled-back change records nothing. Sections of
  type `:blueprint` record `product_*` events, which the Audit Log labels "Template"; other
  sections record `section_*` events.

  Commands do not authorize the actor: callers keep their existing authorization, and checks
  that already lived in a moved function (such as the course builder's creation rights) still
  run inside the transaction. The writes live in private modules under this namespace, so this
  module is the only way to make them.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export internal modules. Outgoing checks are off
  # because this boundary calls into Oli, which depends on it; incoming checks stay on.
  use Boundary, top_level?: true, exports: [], check: [out: false]

  alias Oli.Auditing.Context
  alias Oli.Delivery.SectionCreationRequest
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.Audited.Lifecycle
  alias Oli.Publishing.Publications.Publication

  @type command_error ::
          :invalid_request
          | :not_found
          | :nested_transaction
          | :unauthorized
          | Ecto.Changeset.t()
          | Oli.Auditing.Error.t()
          | term()

  @doc """
  Creates a section from a course builder request and records `section_created`.

  Keeps the course builder's behavior: the request's actor is reloaded and authorized for its
  delivery mode, an LTI context that already has a section for the authorized deployment
  returns that section without creating or recording anything, and the source (publication,
  product, or previous section) is resolved inside the creation transaction. A user actor is
  enrolled as instructor; that enrollment is part of the creation, not a separate event.

  `context` must name the request's actor; otherwise the command returns `:invalid_request`.
  Returns `{:ok, section_id, section_slug}`.
  """
  @spec create_section(Context.t(), SectionCreationRequest.t()) ::
          {:ok, pos_integer(), String.t()} | {:error, command_error()}
  def create_section(%Context{} = context, %SectionCreationRequest{} = request),
    do: Lifecycle.create_section(context, request)

  def create_section(_context, _request), do: {:error, :unauthorized}

  @doc """
  Creates a section from `publication` with `attrs` and records `section_created`, for
  creation paths outside the course builder (independent instructors, Scenarios, automation
  setup). It runs in the caller's transaction when there is one.

  Options:
    * `:rebuild` - `true` rebuilds the contained pages and objectives (default `false`)
    * `:enroll` - a `User` enrolled as instructor (default none)
    * `:post_processing` - the post-processing steps to apply, such as `:all` (default none)
  """
  @spec create_section_from_publication(Context.t(), Publication.t(), map(), keyword()) ::
          {:ok, Section.t()} | {:error, command_error()}
  def create_section_from_publication(context, publication, attrs, opts \\ [])

  def create_section_from_publication(
        %Context{} = context,
        %Publication{} = publication,
        attrs,
        opts
      )
      when is_map(attrs) and is_list(opts),
      do: Lifecycle.create_section_from_publication(context, publication, attrs, opts)

  def create_section_from_publication(_context, _publication, _attrs, _opts),
    do: {:error, :invalid_request}

  @doc """
  Creates a section from `product` with `attrs`, rebuilds its contained pages and objectives,
  and records `section_created` with the product's ID, for creation paths outside the course
  builder. It runs in the caller's transaction when there is one.

  Options: `:enroll` (a `User` enrolled as instructor) and `:post_processing`, as in
  `create_section_from_publication/4`.
  """
  @spec create_section_from_product(Context.t(), Section.t(), map(), keyword()) ::
          {:ok, Section.t()} | {:error, command_error()}
  def create_section_from_product(context, product, attrs, opts \\ [])

  def create_section_from_product(
        %Context{} = context,
        %Section{type: :blueprint} = product,
        attrs,
        opts
      )
      when is_map(attrs) and is_list(opts),
      do: Lifecycle.create_section_from_product(context, product, attrs, opts)

  def create_section_from_product(_context, _product, _attrs, _opts),
    do: {:error, :invalid_request}

  @doc """
  Creates a product (course section template) from the latest publication of the project with
  `base_project_slug` and records `product_created`.

  `labels`, `hierarchy`, and `attrs` are the custom labels, the optional custom hierarchy, and
  the additional attributes `Oli.Delivery.Sections.Blueprint.create_blueprint/5` takes.
  """
  @spec create_product(Context.t(), String.t(), String.t(), map() | nil, term(), map()) ::
          {:ok, Section.t()} | {:error, command_error()}
  def create_product(context, base_project_slug, title, labels, hierarchy \\ nil, attrs \\ %{})

  def create_product(%Context{} = context, base_project_slug, title, labels, hierarchy, attrs)
      when is_binary(base_project_slug) and is_map(attrs),
      do: Lifecycle.create_product(context, base_project_slug, title, labels, hierarchy, attrs)

  def create_product(_context, _slug, _title, _labels, _hierarchy, _attrs),
    do: {:error, :invalid_request}

  @doc """
  Duplicates `product` with `attrs` and records `product_created` for the copy, with
  `creation_source: "product_copy"` and the source product's ID.
  """
  @spec duplicate_product(Context.t(), Section.t(), map()) ::
          {:ok, Section.t()} | {:error, command_error()}
  def duplicate_product(context, product, attrs \\ %{})

  def duplicate_product(%Context{} = context, %Section{} = product, attrs) when is_map(attrs),
    do: Lifecycle.duplicate_product(context, product, attrs)

  def duplicate_product(_context, _product, _attrs), do: {:error, :invalid_request}

  @doc """
  Archives `section` (status `:archived`) and records `section_archived` or `product_archived`
  with the status before and after. A section already archived records nothing.
  """
  @spec archive_section(Context.t(), Section.t()) ::
          {:ok, Section.t()} | {:error, command_error()}
  def archive_section(%Context{} = context, %Section{} = section),
    do: Lifecycle.archive_section(context, section)

  def archive_section(_context, _section), do: {:error, :invalid_request}

  @doc """
  Deletes `section` (status `:deleted`; the row is kept) and records `section_deleted` or
  `product_deleted`. A section already deleted records nothing.
  """
  @spec delete_section(Context.t(), Section.t()) ::
          {:ok, Section.t()} | {:error, command_error()}
  def delete_section(%Context{} = context, %Section{} = section),
    do: Lifecycle.delete_section(context, section)

  def delete_section(_context, _section), do: {:error, :invalid_request}
end
