defmodule Oli.Delivery.Paywall.Payment do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Modeling of a payment.

  Payments can be one of these types: direct, deferred, bypass or invalidated.
  - A direct payment is a payment made by a student through a system supported payment provider (e.g. Stripe or Cashnet).
  - A deferred payment is a payment record that can be created by the system but not "applied" to
  any enrollment at the time of creation. In this deferred case, the payment code is made available
  to a third-party bookstore to be sold to a student.  The student then redeems the code in
  this system (which then "applies" the payment to the enrollment).
  - A bypass payment is a payment that is set by an admin on behalf of a student.
  - An invalidated payment is a payment that has been marked as invalid by an admin.

  The "code" attribute is a random number, guaranteed to be unique, that is non-ordered and thus
  not "guessable" by a malicious actor.  Convenience routines for expressing this code as a
  human readable string of the form: "XV7-JKR4", where the integer (big int) codes are expressed
  in Crockford Base 32 a variant of a standard base 32 encoding that substitutes potentially confusing
  characters in an aim towards maximizing human readability.
  """

  schema "payments" do
    field :type, Ecto.Enum, values: [:direct, :deferred, :bypass, :invalidated], default: :direct
    field :code, :integer
    field :generation_date, :utc_datetime
    field :application_date, :utc_datetime
    field :amount, Money.Ecto.Map.Type
    field :provider_type, Ecto.Enum, values: [:stripe, :cashnet], default: :stripe
    field :provider_id, :string
    field :provider_payload, :map
    field :pending_user_id, :integer
    field :pending_section_id, :integer
    field :bypassed_by_user_id, :integer
    field :invalidated_by_user_id, :integer

    belongs_to :section, Oli.Delivery.Sections.Section
    belongs_to :enrollment, Oli.Delivery.Sections.Enrollment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(section, attrs) do
    section
    |> cast(attrs, [
      :type,
      :code,
      :generation_date,
      :application_date,
      :amount,
      :provider_type,
      :provider_id,
      :provider_payload,
      :pending_user_id,
      :pending_section_id,
      :section_id,
      :enrollment_id,
      :bypassed_by_user_id,
      :invalidated_by_user_id
    ])
    |> validate_required([:type, :generation_date, :amount, :section_id])
  end

  def to_human_readable(code) do
    CrockfordBase32.encode(code) |> partition(partitions: 2)
  end

  def from_human_readable(human_readable_code) do
    CrockfordBase32.decode_to_integer(human_readable_code)
  end

  defp partition(binary, opts) do
    case Keyword.get(opts, :partitions, 0) do
      count when count in [0, 1] ->
        binary

      count ->
        split([], binary, count)
        |> Enum.reverse()
        |> Enum.join("-")
    end
  end

  defp split(parts, binary, 1), do: [binary | parts]

  defp split(parts, binary, count) do
    len = div(String.length(binary), count)
    {part, rest} = String.split_at(binary, len)
    split([part | parts], rest, count - 1)
  end
end
