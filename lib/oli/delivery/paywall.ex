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
  alias Oli.Delivery.Paywall.AccessSummary

  @maximum_batch_size 500

  @doc """
  Summarizes a users ability to access a course section, taking into account the paywall configuration
  for that course section.

  Returns an `%AccessSummary` struct which details the following:
  1. Whether or not the user can access the course material
  2. A reason for why the user can or cannot access
  3. The number of days remaining (in whole numbers) if the user is accessing the material
     during a grace period window
  """
  def summarize_access(_, %Section{requires_payment: false}), do: AccessSummary.build_no_paywall()

  def summarize_access(
        %User{id: id} = user,
        %Section{slug: slug, requires_payment: true} = section
      ) do
    if Sections.is_instructor?(user, slug) or Sections.is_admin?(user, slug) do
      AccessSummary.instructor()
    else
      enrollment = Sections.get_enrollment(slug, id)

      if is_nil(enrollment) and section.requires_enrollment do
        AccessSummary.not_enrolled()
      else
        if section.pay_by_institution do
          AccessSummary.pay_by_institution()
        else
          case has_paid?(enrollment) do
            true ->
              AccessSummary.paid()

            _ ->
              case within_grace_period?(enrollment, section) do
                true ->
                  grace_period_seconds_remaining(enrollment, section)
                  |> AccessSummary.within_grace()

                _ ->
                  AccessSummary.not_paid()
              end
          end
        end
      end
    end
  end

  defp has_paid?(nil), do: false

  defp has_paid?(%Enrollment{id: id}) do
    query =
      from(
        p in Payment,
        where: p.enrollment_id == ^id,
        limit: 1,
        select: p
      )

    case Repo.all(query) do
      [] -> false
      _ -> true
    end
  end

  defp within_grace_period?(nil, _), do: false

  defp within_grace_period?(_, %Section{has_grace_period: false}), do: false

  defp within_grace_period?(%Enrollment{inserted_at: inserted_at}, %Section{
         grace_period_days: days,
         grace_period_strategy: strategy,
         start_date: start_date
       }) do
    case strategy do
      :relative_to_section ->
        case start_date do
          nil ->
            false

          _ ->
            case Date.compare(Date.utc_today(), Date.add(start_date, days)) do
              :lt -> true
              :eq -> true
              _ -> false
            end
        end

      :relative_to_student ->
        Date.compare(Date.utc_today(), Date.add(inserted_at, days)) == :lt
    end
  end

  defp grace_period_seconds_remaining(%Enrollment{inserted_at: inserted_at}, %Section{
         grace_period_days: days,
         grace_period_strategy: strategy,
         start_date: start_date
       }) do
    case strategy do
      :relative_to_section ->
        case start_date do
          nil -> 0
          _ -> -DateTime.diff(DateTime.utc_now(), DateTime.add(start_date, days * 24 * 60 * 60))
        end

      :relative_to_student ->
        -DateTime.diff(DateTime.utc_now(), DateTime.add(inserted_at, days * 24 * 60 * 60))
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
    Given a section (blueprint) calculate the cost to use it for
    a specific institution, taking into account any product-wide and product-specific discounts
    this institution has.

      Returns {:ok, %Money{}} or {:error, reason}
  """
  @spec section_cost_from_product(%Section{}, %Institution{}) :: {:ok, %Money{}} | {:error, any}
  def section_cost_from_product(
        %Section{requires_payment: true, id: id, amount: amount},
        %Institution{id: institution_id}
      ) do
    discounts =
      from(d in Discount,
        # Institution-wide discounts
        # Section-specific discounts for the given institution
        where:
          d.institution_id == ^institution_id and
            (is_nil(d.section_id) or
               d.section_id == ^id),
        select: d
      )
      |> Repo.all()

    # Remove any institution-wide discounts if an institution and section specific discount exists
    discounts =
      case Enum.filter(discounts, fn d -> !is_nil(d.section_id) end) do
        [] -> discounts
        filtered_discounts -> filtered_discounts
      end

    # Now calculate the product cost, taking into account a discount
    case discounts do
      [] ->
        {:ok, amount}

      [%Discount{type: :percentage, percentage: percentage}] ->
        {:ok, discount_amount} =
          amount
          |> Money.mult(round(percentage))
          |> elem(1)
          |> Money.div(100)

        Money.sub(amount, discount_amount)

      [%Discount{amount: amount}] ->
        {:ok, amount}
    end
  end

  def section_cost_from_product(%Section{requires_payment: true, amount: amount}, nil),
    do: {:ok, amount}

  def section_cost_from_product(%Section{requires_payment: false}, _),
    do: {:ok, Money.new(:USD, 0)}

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
            update_payment(payment, %{
              enrollment_id: id,
              pending_user_id: user.id,
              pending_section_id: section.id,
              application_date: DateTime.utc_now()
            })

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
  Get the last X(quantity) payment codes for the given product.
  """
  def list_payments_by_count(product_slug, count) do
    query =
      from(
        p in Payment,
        left_join: s in Section,
        on: p.section_id == s.id,
        where: s.slug == ^product_slug,
        limit: ^count,
        select: p,
        order_by: [desc: :inserted_at]
      )

    Repo.all(query)
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
  Creates a new pending payment, ensuring that no other payments exists for this user
  and section.
  """
  def create_pending_payment(%User{id: user_id}, %Section{id: section_id}, attrs) do
    Oli.Repo.transaction(fn _ ->
      query =
        from(
          p in Payment,
          where: p.pending_section_id == ^section_id and p.pending_user_id == ^user_id
        )

      case Oli.Repo.one(query) do
        # No payment record found for this user in this section
        nil ->
          case create_payment(
                 Map.merge(attrs, %{pending_user_id: user_id, pending_section_id: section_id})
               ) do
            {:ok, r} -> r
            {:error, e} -> Oli.Repo.rollback(e)
          end

        # A payment found, but this payment was never finalized. We will reuse this
        # payment record.
        %Payment{enrollment_id: nil, application_date: nil} = p ->
          case update_payment(p, attrs) do
            {:ok, r} -> r
            {:error, e} -> Oli.Repo.rollback(e)
          end

        _ ->
          Oli.Repo.rollback({:payment_already_exists})
      end
    end)
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

  # ------------------------------------------
  # Discounts

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

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking discount changes.
  ## Examples
      iex> change_discount(discount)
      %Ecto.Changeset{data: %Discount{}}
  """
  def change_discount(%Discount{} = discount, attrs \\ %{}),
    do: Discount.changeset(discount, attrs)

  @doc """
  Deletes a discount.
  ## Examples
      iex> delete_discount(discount)
      {:ok, %Discount{}}
      iex> delete_discount(discount)
      {:error, changeset}
  """
  def delete_discount(%Discount{} = discount),
    do: Repo.delete(discount)

  @doc """
  Gets a discount by clauses. Will raise an error if
  more than one matches the criteria.
  ## Examples
      iex> get_discount_by!(%{section_id: 1})
      %Discount{}
      iex> get_discount_by!(%{section_id: 123})
      nil
      iex> get_discount_by!(%{section_id: 2, u})
      Ecto.MultipleResultsError
  """
  def get_discount_by!(clauses),
    do: Repo.get_by(Discount, clauses) |> Repo.preload([:institution])

  @doc """
  Gets the discounts of a product
  ## Examples
      iex> get_product_discounts!(1)
      [%Discount{}, %Discount{}, ...]
      iex> get_product_discounts!(123)
      []
  """
  def get_product_discounts(product_id) do
    Repo.all(
      from(
        d in Discount,
        where: d.section_id == ^product_id,
        select: d,
        preload: [:institution, :section]
      )
    )
  end

  @doc """
  Gets a discount by institution id and section_id == nil
  ## Examples
      iex> get_institution_wide_discount!(1)
      %Discount{}
      iex> get_institution_wide_discount!(123)
      nil
      iex> get_institution_wide_discount!(2)
      Ecto.MultipleResultsError
  """
  def get_institution_wide_discount!(institution_id) do
    Repo.one(
      from(
        d in Discount,
        where: d.institution_id == ^institution_id and is_nil(d.section_id),
        select: d
      )
    )
  end

  @doc """
  Updates a discount.
  ## Examples
      iex> update_discount(discount, %{name: new_value})
      {:ok, %Discount{}}
      iex> update_discount(discount, %{name: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_discount(%Discount{} = discount, attrs) do
    discount
    |> Discount.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Create or update (if exists) a discount.
  ## Examples
      iex> create_or_update_discount(discount, %{name: new_value})
      {:ok, %Discount{}}
      iex> create_or_update_discount(discount, %{name: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_or_update_discount(%{institution_id: nil} = attrs),
    do:
      {:error,
       Ecto.Changeset.add_error(
         Discount.changeset(%Discount{}, attrs),
         :institution,
         "can't be blank"
       )}

  def create_or_update_discount(%{section_id: nil} = attrs) do
    case get_institution_wide_discount!(attrs.institution_id) do
      nil -> %Discount{}
      discount -> discount
    end
    |> Discount.changeset(attrs)
    |> Repo.insert_or_update()
  end

  def create_or_update_discount(attrs) do
    case get_discount_by!(%{
           section_id: attrs.section_id,
           institution_id: attrs.institution_id
         }) do
      nil -> %Discount{}
      discount -> discount
    end
    |> Discount.changeset(attrs)
    |> Repo.insert_or_update()
  end
end
