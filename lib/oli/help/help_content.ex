defmodule Oli.Help.HelpContent do
  defstruct [
    :subject,
    :message,
    :timestamp,
    :ip_address,
    :location,
    :user_agent,
    :agent_accept,
    :agent_language,
    :cookies_enabled,
    :account_created,
    :screen_size,
    :browser_size,
    :browser_plugins,
    :operating_system,
    :browser_info,
    :screenshots,
    :course_data,
    :requester_data,
    :support_email
  ]

  @subjects %{
    "help_access_code" => "Access Code",
    "help_account_info" => "Account Information",
    "help_add_course" => "Adding / Linking a Course",
    "help_assignments" => "Assignments",
    "help_browser" => "Browser Issue",
    "help_content_question_or_error" => "Content Question or Error",
    "help_content_remix" => "Content Remix",
    "help_section_management_scheduling" => "Course Section Management - Scheduling",
    "help_section_management_setup" => "Course Section Management - SetUp",
    "help_section_management_grades" => "Course Section Management - Grades",
    "help_section_management_other" => "Course Section Management - Other",
    "help_course_setup" => "Course Setup",
    "help_course_enrollments" => "Course Enrollments",
    "help_login" => "Login",
    "help_lms_integration" => "LMS Integration",
    "help_page_loading" => "Page Loading Issue",
    "help_password" => "Password",
    "help_payment" => "Payment or Purchase",
    "help_request_content" => "Request - Content",
    "help_request_feature" => "Request - Feature",
    "help_request_product_demo" => "Request - Product Demo",
    "help_request_other" => "Request - Other",
    "help_ui_ux" => "UI/UX"
  }

  def parse(%{
        "subject" => subject,
        "message" => message,
        "timestamp" => timestamp,
        "ip_address" => ip_address,
        "location" => location,
        "user_agent" => user_agent,
        "agent_accept" => agent_accept,
        "agent_language" => agent_language,
        "cookies_enabled" => cookies_enabled,
        "account_created" => account_created,
        "screen_size" => screen_size,
        "browser_size" => browser_size,
        "browser_plugins" => browser_plugins,
        "operating_system" => operating_system,
        "browser_info" => browser_info,
        "course_data" => course_data,
        "screenshots" => screenshots,
        "requester_data" => %Oli.Help.RequesterData{} = requester_data,
        "support_email" => support_email
      }) do
    help_content = %Oli.Help.HelpContent{
      subject: subject,
      message: message,
      timestamp: timestamp,
      ip_address: ip_address,
      location: location,
      user_agent: user_agent,
      agent_accept: agent_accept,
      agent_language: agent_language,
      cookies_enabled: cookies_enabled,
      account_created: account_created,
      screen_size: screen_size,
      browser_size: browser_size,
      browser_plugins: browser_plugins,
      operating_system: operating_system,
      browser_info: browser_info,
      course_data: course_data,
      screenshots: screenshots,
      requester_data: requester_data,
      support_email: support_email
    }

    {:ok, help_content}
  end

  def parse(_) do
    {:error, "incomplete help request"}
  end

  def get_subject(key) do
    Map.get(@subjects, key)
  end

  def list_subjects, do: @subjects
end
