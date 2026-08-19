defmodule Oli.Scenarios.Directives.DirectiveAttrs do
  @moduledoc """
  Shared helpers for normalizing scenario directive attributes before persistence.
  """

  @spec blueprint_attrs(map()) :: map()
  def blueprint_attrs(directive_attrs) do
    %{}
    |> maybe_put("requires_payment", Map.get(directive_attrs, :requires_payment))
    |> maybe_put(
      "payment_options",
      stringify_atom(Map.get(directive_attrs, :payment_options))
    )
    |> maybe_put("pay_by_institution", Map.get(directive_attrs, :pay_by_institution))
    |> maybe_put("amount", Map.get(directive_attrs, :amount))
    |> maybe_put("has_grace_period", Map.get(directive_attrs, :has_grace_period))
    |> maybe_put("grace_period_days", grace_period_days(directive_attrs))
    |> maybe_put(
      "grace_period_strategy",
      stringify_atom(Map.get(directive_attrs, :grace_period_strategy))
    )
  end

  @spec section_attrs(map()) :: map()
  def section_attrs(directive_attrs) do
    %{
      title: Map.fetch!(directive_attrs, :title),
      registration_open: Map.fetch!(directive_attrs, :registration_open),
      open_and_free: Map.fetch!(directive_attrs, :open_and_free),
      requires_enrollment: Map.fetch!(directive_attrs, :requires_enrollment),
      assistant_enabled: Map.get(directive_attrs, :assistant_enabled),
      requires_payment: Map.get(directive_attrs, :requires_payment),
      payment_options: Map.get(directive_attrs, :payment_options),
      pay_by_institution: Map.get(directive_attrs, :pay_by_institution),
      amount: money_from_map(Map.get(directive_attrs, :amount)),
      has_grace_period: grace_period_enabled(directive_attrs),
      grace_period_days: grace_period_days(directive_attrs),
      grace_period_strategy: Map.get(directive_attrs, :grace_period_strategy),
      start_date: Map.get(directive_attrs, :start_date),
      end_date: Map.get(directive_attrs, :end_date),
      type: Map.get(directive_attrs, :type) || :enrollable,
      slug: Map.get(directive_attrs, :slug)
    }
    |> compact()
  end

  @spec discount_attrs(map()) :: map()
  def discount_attrs(directive_attrs) do
    %{
      type: Map.get(directive_attrs, :type),
      percentage: Map.get(directive_attrs, :percentage),
      amount: money_from_map(Map.get(directive_attrs, :amount)),
      bypass_paywall: Map.get(directive_attrs, :bypass_paywall, false)
    }
    |> compact()
  end

  @spec money_from_map(nil | map()) :: nil | Money.t()
  def money_from_map(nil), do: nil

  def money_from_map(%{"amount" => amount, "currency" => currency}),
    do: Money.new(amount, currency)

  @spec compact(map()) :: map()
  def compact(attrs), do: Map.reject(attrs, fn {_key, value} -> is_nil(value) end)

  defp grace_period_enabled(directive_attrs) do
    case {Map.get(directive_attrs, :requires_payment),
          Map.get(directive_attrs, :has_grace_period)} do
      {nil, nil} -> nil
      {nil, value} -> value
      {false, _value} -> false
      {true, nil} -> true
      {true, value} -> value
    end
  end

  defp grace_period_days(directive_attrs) do
    if Map.get(directive_attrs, :requires_payment) != false and
         Map.get(directive_attrs, :has_grace_period) != false do
      Map.get(directive_attrs, :grace_period_days)
    else
      nil
    end
  end

  defp stringify_atom(nil), do: nil
  defp stringify_atom(value) when is_atom(value), do: Atom.to_string(value)

  defp maybe_put(attrs, _key, nil), do: attrs
  defp maybe_put(attrs, key, value), do: Map.put(attrs, key, value)
end
