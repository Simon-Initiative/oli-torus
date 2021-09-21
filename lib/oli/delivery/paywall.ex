defmodule Oli.Delivery.Paywall do
  alias Oli.Repo
  alias Oli.Delivery.Paywall.Payment
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.Blueprint

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
      result =
        [1..number_of_codes]
        |> Enum.reduce_while([], fn _, all ->
          case create_payment(%{
                 type: :deferred,
                 generation_date: now,
                 application_date: nil,
                 amount: amount,
                 section_id: id,
                 enrollment_id: nil
               }) do
            {:ok, payment} -> {:cont, [payment | all]}
            {:error, e} -> {:halt, e}
          end
        end)

      case result do
        all when is_list(all) -> all
        e -> Repo.rollback(e)
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
end
