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
      }) do
    help_requester_data = %Oli.Help.RequesterData{
      requester_name: requester_name,
      requester_email: requester_email,
      requester_type: requester_type,
      requester_account_url: requester_account_url,
      student_report_url: student_report_url
    }

    {:ok, help_requester_data}
  end

  def parse(_) do
    {:error, "Help requester data is incomplete."}
  end
end
