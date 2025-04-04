defmodule Oli.Delivery.Sections.Certificate do
  use Ecto.Schema
  import Ecto.Changeset
  import Oli.Utils, only: [validate_greater_than_or_equal: 4]

  alias Oli.Delivery.Sections.GrantedCertificate
  alias Oli.Delivery.Sections.Section

  @assessments_options [:all, :custom]

  @derive {Jason.Encoder, except: [:id, :section, :granted_certificate, :__meta__]}

  schema "certificates" do
    field :required_discussion_posts, :integer, default: 0
    field :required_class_notes, :integer, default: 0
    field :min_percentage_for_completion, :float, default: 75.0
    field :min_percentage_for_distinction, :float, default: 95.0
    field :assessments_apply_to, Ecto.Enum, values: @assessments_options, default: :all
    field :custom_assessments, {:array, :integer}, default: []
    field :requires_instructor_approval, :boolean, default: false

    field :title, :string
    field :description, :string

    field :admin_name1, :string
    field :admin_title1, :string
    field :admin_name2, :string
    field :admin_title2, :string
    field :admin_name3, :string
    field :admin_title3, :string

    field :logo1, :binary
    field :logo2, :binary
    field :logo3, :binary

    belongs_to :section, Section

    has_one :granted_certificate, GrantedCertificate

    timestamps(type: :utc_datetime)
  end

  @required_fields [
    :required_discussion_posts,
    :required_class_notes,
    :min_percentage_for_completion,
    :min_percentage_for_distinction,
    :assessments_apply_to,
    :title,
    :description,
    :section_id
  ]

  @optional_fields [
    :custom_assessments,
    :requires_instructor_approval,
    :admin_name1,
    :admin_title1,
    :admin_name2,
    :admin_title2,
    :admin_name3,
    :admin_title3,
    :logo1,
    :logo2,
    :logo3
  ]

  @all_fields @required_fields ++ @optional_fields

  def changeset(params \\ %{}) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(certificate, params) do
    certificate
    |> cast(params, @all_fields)
    |> validate_required(@required_fields)
    |> validate_greater_than_or_equal(
      :min_percentage_for_completion,
      :min_percentage_for_distinction,
      allow_equal: true
    )
    |> validate_assessments()
    |> assoc_constraint(:section)
  end

  defp validate_assessments(changeset) do
    {_, custom_assessments} = fetch_field(changeset, :custom_assessments)
    {_, assessments_apply_to} = fetch_field(changeset, :assessments_apply_to)

    case {custom_assessments, assessments_apply_to} do
      {[], :custom} ->
        message = "scored pages must not be empty"
        add_error(changeset, :custom_assessments, message, to_field: :assessments_apply_to)

      _ ->
        changeset
    end
  end
end
