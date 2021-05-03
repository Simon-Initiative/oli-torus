defmodule Oli.Utils.LoadTesting do

  def enabled?() do
    Application.fetch_env!(:oli, :load_testing_mode) == :enabled
  end

end
