defmodule Oli.Delivery.Paywall.Payment do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Modeling of a payment.

  Payments can be one of two types: direct or deferred.  A direct payment is a
  payment made by a student through a system supported payment provider (e.g. Stripe or Cashnet).
  A deferred payment is a payment record that can be created by the system but not "applied" to
  any enrollment at the time of creation. In this deferred case, the payment code is made available
  to a third-party bookstore to be sold to a student.  The student then redeems the code in
  this system (which then "applies" the payment to the enrollment).

  The "code" attribute is a random number, guaranteed to be unique, that is non-ordered and thus
  not "guessable" by a malicious actor.  Convenience routines for expressing this code as a
  human readable string of the form: "XV7-JKR4", where the integer (big int) codes are expressed
  in Crockford Base 32 a variant of a standard base 32 encoding that substitutes potentially confusing
  characters in an aim towards maximizing human readability.
  """

  schema "payments" do
    field :type, Ecto.Enum, values: [:direct, :deferred], default: :direct
    field :code, :integer
    field :generation_date, :utc_datetime
    field :application_date, :utc_datetime
    field :amount, Money.Ecto.Map.Type

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
      :section_id,
      :enrollment_id
    ])
    |> validate_required([:type, :code, :generation_date, :amount, :section_id])
  end

  def to_human_readable(code) do
    Base32Crockford.encode(code, partitions: 2)
  end

  def from_human_readable(human_readable_code) do
    Base32Crockford.decode(human_readable_code)
  end
end
