defmodule Oli.Delivery.Attempts.StartAttemptPolicy do
  @moduledoc """
  Shared policy for checks that must pass before starting a graded attempt.
  """

  alias Oli.Delivery.Settings
  alias Oli.Delivery.Settings.Combined

  @type denial_reason :: :password_required | :incorrect_password | :before_start_date

  @spec validate(Combined.t(), keyword()) :: :ok | {:error, denial_reason()}
  def validate(%Combined{} = effective_settings, opts \\ []) do
    password = Keyword.get(opts, :password)

    with :ok <- validate_password(effective_settings, password),
         {:allowed} <- Settings.check_start_date(effective_settings) do
      :ok
    else
      {:before_start_date} -> {:error, :before_start_date}
      {:error, _reason} = error -> error
    end
  end

  defp validate_password(%Combined{password: password}, _received_password)
       when password in [nil, ""],
       do: :ok

  defp validate_password(%Combined{password: password}, received_password)
       when received_password in [nil, ""],
       do: if(password in [nil, ""], do: :ok, else: {:error, :password_required})

  defp validate_password(%Combined{password: password}, password), do: :ok
  defp validate_password(%Combined{}, _received_password), do: {:error, :incorrect_password}
end
