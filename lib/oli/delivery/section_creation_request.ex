defmodule Oli.Delivery.SectionCreationRequest do
  @moduledoc """
  Command struct for course section creation: who is asking, which source, the form
  attributes and the delivery specification.

  The actor is carried as a tagged id and reloaded at the boundary. Enrollment follows
  from it: a user actor is enrolled as instructor, an author actor enrolls nobody.
  """

  alias Oli.Accounts.{Author, User}
  alias Oli.Delivery.Sections.SectionSpecification

  @attr_keys [
    :title,
    :course_section_number,
    :class_modality,
    :class_days,
    :start_date,
    :end_date,
    :preferred_scheduling_time,
    :timezone
  ]

  # Source ids address bigint primary keys; anything larger cannot name a row and must not
  # reach the database.
  @max_id 9_223_372_036_854_775_807

  @enforce_keys [:actor, :source, :attrs, :section_spec]
  defstruct [:actor, :source, :attrs, :section_spec]

  @type actor :: {:user, integer()} | {:author, integer()}
  @type source :: {:publication, integer()} | {:product, integer()} | {:section, integer()}

  @type t :: %__MODULE__{
          actor: actor(),
          source: source(),
          attrs: map(),
          section_spec: struct()
        }

  @doc """
  Builds a request from the caller's account, a `<kind>:<id>` source identifier, the form
  attributes and a section specification. Anything unparseable is `{:error, :unauthorized}`.
  """
  @spec new(User.t() | Author.t(), String.t(), map(), struct()) ::
          {:ok, t()} | {:error, :unauthorized}
  def new(account, source, attrs, section_spec)

  def new(%User{id: id}, source, attrs, section_spec) when is_integer(id),
    do: build({:user, id}, source, attrs, section_spec)

  def new(%Author{id: id}, source, attrs, section_spec) when is_integer(id),
    do: build({:author, id}, source, attrs, section_spec)

  def new(_account, _source, _attrs, _section_spec), do: {:error, :unauthorized}

  @doc """
  The account that acts when a session carries both an author and a user.

  An administrator acts as the author, as `Mount.for/2` does elsewhere: the section is
  audited to the author and enrolls nobody.
  """
  @spec actor_account(Author.t() | nil, User.t() | nil) :: Author.t() | User.t() | nil
  def actor_account(author, user) do
    if Oli.Accounts.is_admin?(author), do: author, else: user || author
  end

  @doc """
  Whether a value can name a source row. Re-checked at the service boundary, since a
  request can be built without `new/4`.
  """
  @spec valid_id?(term()) :: boolean()
  def valid_id?(id), do: is_integer(id) and id > 0 and id <= @max_id

  @doc """
  The attribute keys a request may carry to the created section.
  """
  @spec attr_keys() :: [atom()]
  def attr_keys, do: @attr_keys

  @doc """
  Keeps only the attribute keys a request may carry. Re-applied at the service boundary,
  since a request can be built without `new/4`.
  """
  @spec take_attrs(map()) :: map()
  def take_attrs(attrs) when is_map(attrs), do: Map.take(attrs, @attr_keys)
  def take_attrs(_attrs), do: %{}

  defp build(actor, source, attrs, section_spec) do
    with {:ok, parsed_source} <- parse_source(source),
         {:ok, section_spec} <- validate_spec(section_spec) do
      {:ok,
       %__MODULE__{
         actor: actor,
         source: parsed_source,
         attrs: take_attrs(attrs),
         section_spec: section_spec
       }}
    end
  end

  defp parse_source("publication:" <> id), do: parse_id(:publication, id)
  defp parse_source("product:" <> id), do: parse_id(:product, id)
  defp parse_source("section:" <> id), do: parse_id(:section, id)
  defp parse_source(_source), do: {:error, :unauthorized}

  defp parse_id(kind, id) do
    case Integer.parse(id) do
      {parsed_id, ""} ->
        if valid_id?(parsed_id), do: {:ok, {kind, parsed_id}}, else: {:error, :unauthorized}

      _ ->
        {:error, :unauthorized}
    end
  end

  defp validate_spec(%SectionSpecification.Direct{} = spec), do: {:ok, spec}
  defp validate_spec(%SectionSpecification.Lti{} = spec), do: {:ok, spec}
  defp validate_spec(_spec), do: {:error, :unauthorized}
end
