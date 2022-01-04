defmodule Oli.Help.HelpContent do
  defstruct [
    :full_name,
    :email,
    :subject,
    :message,
    :timestamp,
    :ip_address,
    :location,
    :user_agent,
    :agent_accept,
    :agent_language,
    :cookies_enabled,
    :account_email,
    :account_name,
    :account_role,
    :account_created
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
        "full_name" => full_name,
        "email" => email,
        "subject" => subject,
        "message" => message,
        "timestamp" => timestamp,
        "ip_address" => ip_address,
        "location" => location,
        "user_agent" => user_agent,
        "agent_accept" => agent_accept,
        "agent_language" => agent_language,
        "cookies_enabled" => cookies_enabled,
        "account_email" => account_email,
        "account_name" => account_name,
        "account_created" => account_created
      }) do
    help_content = %Oli.Help.HelpContent{
      full_name: full_name,
      email: email,
      subject: subject,
      message: message,
      timestamp: timestamp,
      ip_address: ip_address,
      location: location,
      user_agent: user_agent,
      agent_accept: agent_accept,
      agent_language: agent_language,
      cookies_enabled: cookies_enabled,
      account_email: account_email,
      account_name: account_name,
      account_created: account_created
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
