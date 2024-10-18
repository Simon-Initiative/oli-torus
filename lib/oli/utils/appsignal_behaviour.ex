defmodule Oli.Utils.AppsignalBehaviour do
  @callback capture_error(String.t()) :: any()
end
