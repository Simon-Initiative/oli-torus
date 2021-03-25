defmodule Oli.Lti_1p3.Utils do

  @doc """
  Returns true if the lti_params contain the oli open_and_free flag
  """
  def open_and_free_user?(%{
    "https://oli.cmu.edu/session" => %{
      "open_and_free" => true,
    }} = _lti_params
  ) do
    true
  end

  def open_and_free_user?(_lti_params), do: false

end
