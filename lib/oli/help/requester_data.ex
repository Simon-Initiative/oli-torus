defmodule Oli.Help.RequesterData do
  defstruct [
    :requester_name,
    :requester_email,
    :requester_type,
    :requester_account_url,
    :student_report_url
  ]

  def parse(%{
        "requester_account_url" => requester_account_url,
        "requester_email" => requester_email,
        "requester_name" => requester_name,
        "requester_type" => requester_type,
        "student_report_url" => student_report_url
      })
      when not is_nil(requester_email) and not is_nil(requester_name) do
    help_requester_data = %Oli.Help.RequesterData{
      requester_name: requester_name,
      requester_email: requester_email,
      requester_type: requester_type,
      requester_account_url: requester_account_url,
      student_report_url: student_report_url
    }

    {:ok, help_requester_data}
  end

  def parse(requester_data) do
    required_fields =
      Enum.reduce(requester_data, [], fn
        {"requester_email", nil}, acc -> acc ++ ["email"]
        {"requester_name", nil}, acc -> acc ++ ["name"]
        _, acc -> acc
      end)
      |> Enum.join(" and ")

    {:error, "Requester data is incomplete. Required field(s): #{required_fields}"}
  end
end
