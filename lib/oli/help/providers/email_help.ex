defmodule Oli.Help.Providers.EmailHelp do
  @behaviour Oli.Help.Dispatcher

  alias Oli.Help.HelpContent
  alias Oli.Help.RequesterData

  @impl Oli.Help.Dispatcher
  def dispatch(%HelpContent{requester_data: %RequesterData{} = requester_data} = contents) do
    help_desk_email = System.get_env("HELP_DESK_EMAIL", "test@example.edu")
    subject = HelpContent.get_subject(contents.subject)
    message = %{message: build_help_message(contents)}
    requester_email = requester_data.requester_email

    email =
      Oli.Email.help_desk_email(requester_email, help_desk_email, subject, :help_email, message)

    Oli.Mailer.deliver(email)
  end

  defp build_help_message(contents) do
    message =
      get_general_data(contents) <>
        get_user_account_data(contents) <>
        get_course_data(contents) <>
        get_browser_data(contents) <>
        get_capabilities_data(contents) <>
        get_screenshots_data(contents)

    message
    |> String.replace("\r", "")
    |> String.replace("\n", "<br>")
  end

  defp get_screenshots_data(contents) do
    screenshots =
      for screenshot <- contents.screenshots, into: "" do
        """
        <a href=#{screenshot} target="_blank" rel="noopener noreferrer">
          <img src="#{screenshot}" width="500" />
        </a>
        """
      end

    if Enum.any?(contents.screenshots) do
      """
      SCREENSHOTS
      #{screenshots}
      """
    else
      ""
    end
  end

  defp get_capabilities_data(contents) do
    """
    CAPABILITIES
    Cookies Enabled: #{contents.cookies_enabled}
    <br>
    """
  end

  defp get_browser_data(contents) do
    """
    WEB BROWSER
    Browser: #{contents.browser_info}
    User Agent: #{contents.user_agent}
    Accept: #{contents.agent_accept}
    Language: #{contents.agent_language}
    Screen Size: #{contents.screen_size}
    Browser Size: #{contents.browser_size}
    Operating System: #{contents.operating_system}
    Browser Plugins: #{contents.browser_plugins}
    <br>
    """
  end

  defp get_general_data(contents) do
    requester_name = contents.requester_data.requester_name
    requester_email = contents.requester_data.requester_email
    location = "<a href=\"#{contents.location}\">#{contents.location}</a>"

    """
    On #{contents.timestamp}, #{requester_name} &lt; #{requester_email} &gt; wrote: <br><br>
    #{contents.message}
    <br><br>----------------------------------------------
    <br>
    Timestamp: #{contents.timestamp}
    Ip Address: #{contents.ip_address}
    Location: #{location}
    <br>
    """
  end

  defp get_user_account_data(contents) do
    if String.trim(contents.account_created) != "" do
      requester_name = contents.requester_data.requester_name
      requester_email = contents.requester_data.requester_email
      requester_type = contents.requester_data.requester_type
      student_report_url = contents.requester_data.student_report_url
      requester_account_url = contents.requester_data.requester_account_url

      user_account_url = "<a href=\"#{requester_account_url}\">#{requester_account_url}</a>"

      account_name =
        if requester_type == "Student" do
          "<a href=\"#{student_report_url}\">#{requester_name}</a>"
        else
          requester_name
        end

      """
      USER ACCOUNT
      Name: #{account_name}
      Email: #{requester_email}
      User Type: #{requester_type}
      User Account URL: #{user_account_url}
      Created: #{contents.account_created}
      <br>
      """
    else
      ""
    end
  end

  defp get_course_data(contents) do
    if contents.course_data do
      """
      COURSE DATA
      Title: #{contents.course_data["title"] || ""}
      Start Date: #{contents.course_data["start_date"] || ""}
      End Date: #{contents.course_data["end_date"] || ""}
      Course Managment URL: "<a href=\"#{contents.course_data["course_management_url"]}\">#{contents.course_data["course_management_url"]}</a>"
      Institution: #{if contents.course_data["institution_name"], do: contents.course_data["institution_name"], else: ""}
      <br>
      """
    else
      ""
    end
  end
end
