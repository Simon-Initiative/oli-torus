defmodule Oli.Delivery.Paywall do
  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Delivery.Paywall.Payment
  alias Oli.Delivery.Paywall.Discount
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Institutions.Institution

  @maximum_batch_size 500

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
        WHERE x.new_id NOT IN (SELECT code FROM payments)",
        []
      )

    case query do
      {:ok, %{num_rows: ^count, rows: rows}} ->
        {:ok, List.flatten(rows) |> Enum.map(fn c -> trunc(c) end)}

      {:error, _} ->
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
