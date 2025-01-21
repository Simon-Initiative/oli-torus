defmodule Oli.Delivery.Paywall.AccessSummary do
  alias Oli.Delivery.Paywall.AccessSummary

  defstruct [
    # Boolean indicating whether access is available
    :available,
    # For available, one of:     [:not_paywalled, :instructor, :paid, :within_grace_period, :pay_by_institution]
    :reason,
    # For not-available, one of: [:not_enrolled, :not_paid]
    :grace_period_remaining
  ]

  def build_no_paywall() do
    %AccessSummary{
      available: true,
      reason: :not_paywalled,
      grace_period_remaining: nil
    }
  end

  def instructor() do
    %AccessSummary{
      available: true,
      reason: :instructor,
      grace_period_remaining: nil
    }
  end

  def not_enrolled() do
    %AccessSummary{
      available: false,
      reason: :not_enrolled,
      grace_period_remaining: nil
    }
  end

  def paid() do
    %AccessSummary{
      available: true,
      reason: :paid,
      grace_period_remaining: nil
    }
  end

  def not_paid() do
    %AccessSummary{
      available: false,
      reason: :not_paid,
      grace_period_remaining: nil
    }
  end

  def within_grace(grace_period_remaining) do
    %AccessSummary{
      available: true,
      reason: :within_grace_period,
      grace_period_remaining: grace_period_remaining
    }
  end

  def as_days(grace_period_remaining) do
    grace_period_remaining / (60 * 60 * 24)
  end

  def pay_by_institution() do
    %AccessSummary{
      available: true,
      reason: :pay_by_institution,
      grace_period_remaining: nil
    }
  end

  def has_zero_cost() do
    %AccessSummary{
      available: true,
      reason: :has_zero_cost,
      grace_period_remaining: nil
    }
  end
end
