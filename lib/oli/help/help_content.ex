defmodule Oli.Help.HelpContent do

  defstruct [
    :full_name,
    :email,
    :subject,
    :message
  ]

  def parse(%{"full_name" => full_name, "email" => email, "subject" => subject, "message" => message}) do
    %Oli.Help.HelpContent{
    full_name: full_name,
    email: email,
    subject: subject,
    message: message
    }
  end

  def parse(_) do
    {:error, "invalid feedback"}
  end
end
