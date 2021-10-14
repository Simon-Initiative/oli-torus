defmodule Oli.Delivery.Paywall do
  import Ecto.Query, warn: false

  require Logger

  alias Oli.Repo
  alias Oli.Accounts.User
  alias Oli.Delivery.Paywall.Payment
  alias Oli.Delivery.Paywall.Discount
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Institutions.Institution

  @maximum_batch_size 500

  @doc """
  Determines if a user can access a course section, taking into account paywall settings.
  """
  def can_access?(_, %Section{requires_payment: false}), do: true

  def can_access?(%User{id: id} = user, %Section{slug: slug, requires_payment: true} = section) do
    if Sections.is_instructor?(user, slug) or Sections.is_admin?(user, slug) do
      true
    else
      enrollment = Sections.get_enrollment(slug, id)

      # A student can access a paywalled section if the following two conditions hold:
      # 1. They are enrolled in the section
      # 2. They have either made a payment OR they are within the grace period (if there is one)
      !is_nil(enrollment) and (has_paid?(enrollment) or within_grace_period?(enrollment, section))
    end
  end

  defp has_paid?(%Enrollment{id: id}) do
    query =
      from(
        p in Payment,
        where: p.enrollment_id == ^id,
        select: p
      )

    !is_nil(Repo.one(query))
  end

  defp within_grace_period?(_, %Section{has_grace_period: false}), do: false

  defp within_grace_period?(%Enrollment{inserted_at: inserted_at}, %Section{
         grace_period_days: days,
         grace_period_strategy: strategy,
         start_date: start_date
       }) do
    case strategy do
      :relative_to_section ->
        case start_date do
          nil -> false
          _ -> Date.compare(Date.utc_today(), Date.add(start_date, days)) == :lt
        end

      :relative_to_student ->
        Date.compare(Date.utc_today(), Date.add(inserted_at, days)) == :lt
    end
  end

  @doc """
  Generates a batch of payment codes (aka deferred payments).

  Returns {:ok, [%Payment{}]} on successful creation.

  Can return one of the following specific error conditions:

  {:error, {:invalid_batch_size}} - when the batch size is not valid
  {:error, {:invalid_product}} - when the product slug does not reference a valid product
  {:error, e} - on a database error encountered during creatinon of the payment

  """
  def create_payment_codes(_, number_of_codes) when number_of_codes <= 0,
    do: {:error, {:invalid_batch_size}}

  def create_payment_codes(_, number_of_codes) when number_of_codes > @maximum_batch_size,
    do: {:error, {:invalid_batch_size}}

  def create_payment_codes(product_slug, number_of_codes) do
    case Blueprint.get_active_blueprint(product_slug) do
      nil ->
        {:error, {:invalid_product}}

      %Section{} = section ->
        create_codes_for_section(section, number_of_codes)
    end
  end

  defp create_codes_for_section(%Section{id: id, amount: amount}, number_of_codes) do
    now = DateTime.utc_now()

    Repo.transaction(fn _ ->
      case unique_codes(number_of_codes) do
        {:ok, codes} ->
          result =
            Enum.reverse(codes)
            |> Enum.reduce_while([], fn code, all ->
              case create_payment(%{
                     type: :deferred,
                     code: code,
                     generation_date: now,
                     application_date: nil,
                     amount: amount,
                     section_id: id,
                     enrollment_id: nil
                   }) do
                {:ok, payment} -> {:cont, [payment | all]}
                {:error, e} -> {:halt, {:error, e}}
              end
            end)

          case result do
            {:error, e} -> Repo.rollback(e)
            all -> all
          end

        {:error, e} ->
          Repo.rollback(e)
      end
    end)
  end

  defp unique_codes(count) do
    # Generate a batch of unique integer codes, in one query
    query =
      Ecto.Adapters.SQL.query(
        Oli.Repo,
        "SELECT * FROM (SELECT trunc(random() * (10000000000 - 100000000) + 100000000) AS new_id
        FROM generate_series(1, #{count})) AS x
        WHERE x.new_id NOT IN (SELECT code FROM payments WHERE type = \'deferred\')",
        []
      )

    case query do
      {:ok, %{num_rows: ^count, rows: rows}} ->
        {:ok, List.flatten(rows) |> Enum.map(fn c -> trunc(c) end)}

      {:error, e} ->
        Logger.error("could not generate random codes: #{inspect(e)}")

        {:error, "could not generate random codes"}
    end
  end

  @doc """
  Given a section blueprint (aka a product), calculate the cost to use this product for
  a specific insituttion, taking into account any product-wide and product-specific discounts
  this instituttion has.

  Returns {:ok, %Money{}} or {:error, reason}
  """
  def calculate_product_cost(
        %Section{type: :blueprint, requires_payment: false},
        _
      ),
      do: {:ok, Money.new(:USD, 0)}

  def calculate_product_cost(
        %Section{type: :blueprint, requires_payment: true, amount: amount},
        nil
      ),
      do: {:ok, amount}

  def calculate_product_cost(
        %Section{type: :blueprint, requires_payment: true, id: id, amount: amount},
        %Institution{id: institution_id}
      ) do
    discounts =
      from(d in Discount,
        where:
          (is_nil(d.section_id) and d.institution_id == ^institution_id) or
            (d.section_id == ^id and d.institution_id == ^institution_id),
        select: d
      )
      |> Repo.all()

    # Remove any institution-wide discounts if an institution and section specific discount exists
    discounts =
      case Enum.any?(discounts, fn d -> !is_nil(d.section_id) end) do
        true ->
          Enum.filter(discounts, fn d -> !is_nil(d.section_id) end)

        false ->
          discounts
      end

    # Now calculate the product cost, taking into account a discount
    case discounts do
      [] ->
        {:ok, amount}

      [%Discount{type: :percentage, percentage: percentage}] ->
        Money.mult(amount, percentage)

      [%Discount{amount: amount}] ->
        {:ok, amount}
    end
  end

  @doc """
  Redeems a payment code for a given course section.

  Returns {:ok, %Payment{}} on success, otherwise:
  {:error, {:already_paid}} if the student has already paid for this section
  {:error, {:not_enrolled}} if the student is not enrolled in the section
  {:error, {:unknown_section}} when the section slug does not pertain to a valid section
  {:error, {:unknown_code}} when no deferred payment record is found for `code`
  {:error, {:invalid_code}} when the code is invalid, whether it has already been redeemed or
    if it doesn't pertain to this section or blueprint product

  """
  def redeem_code(human_readable_code, %User{} = user, section_slug) do
    case Payment.from_human_readable(human_readable_code) do
      {:ok, code} ->
        case Sections.get_section_by_slug(section_slug) do
          nil ->
            {:error, {:unknown_section}}

          %Section{blueprint_id: blueprint_id, id: id} = section ->
            case Repo.get_by(Payment, code: code) do
              nil ->
                {:error, {:unknown_code}}

              %Payment{
                type: :deferred,
                application_date: nil,
                section_id: ^id,
                enrollment_id: nil
              } = payment ->
                apply_payment(payment, user, section)

              %Payment{
                type: :deferred,
                application_date: nil,
                section_id: ^blueprint_id,
                enrollment_id: nil
              } = payment ->
                apply_payment(payment, user, section)

              _ ->
                {:error, {:invalid_code}}
            end
        end

      _ ->
        {:error, {:invalid_code}}
    end
  end

  defp apply_payment(payment, user, section) do
    case Sections.get_enrollment(section.slug, user.id) do
      nil ->
        {:error, {:not_enrolled}}

      %{id: id} ->
        case Repo.get_by(Payment, enrollment_id: id) do
          nil ->
            update_payment(payment, %{enrollment_id: id, application_date: DateTime.utc_now()})

          _ ->
            {:error, {:already_paid}}
        end
    end
  end

  @doc """
  List all payments for a product, joined with the enrollment (user and section) if
  the payment has been applied.
  """
  def list_payments(product_slug) do
    case Oli.Delivery.Sections.get_section_by_slug(product_slug) do
      nil ->
        []

      %Section{id: id} ->
        query =
          from(
            p in Payment,
            left_join: e in Enrollment,
            on: e.id == p.enrollment_id,
            left_join: u in User,
            on: e.user_id == u.id,
            left_join: s2 in Section,
            on: e.section_id == s2.id,
            where: p.section_id == ^id,
            select: %{payment: p, section: s2, user: u}
          )

        Repo.all(query)
    end
  end

  @doc """
  Retrieve a payment for a specific provider and id.
  """
  def get_provider_payment(provider_type, provider_id) do
    query =
      from(
        p in Payment,
        where: p.provider_type == ^provider_type and p.provider_id == ^provider_id,
        select: p
      )

    Repo.one(query)
  end

  @doc """
  Creates a payment.
  ## Examples
      iex> create_payment(%{field: value})
      {:ok, %Payment{}}
      iex> create_payment(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_payment(attrs \\ %{}) do
    %Payment{}
    |> Payment.changeset(attrs)
    |> Repo.insert()
  end

  def update_payment(%Payment{} = p, attrs) do
    p
    |> Payment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Creates a discount.
  ## Examples
      iex> create_discount(%{field: value})
      {:ok, %Discount{}}
      iex> create_discount(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_discount(attrs \\ %{}) do
    %Discount{}
    |> Discount.changeset(attrs)
    |> Repo.insert()
  end
end
