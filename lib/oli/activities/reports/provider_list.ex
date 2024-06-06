defmodule Oli.Activities.Reports.ProviderList do
  def report_provider("oli_likert") do
    Module.concat([Oli, Activities, Reports, Providers, OliLikert])
  end
end
