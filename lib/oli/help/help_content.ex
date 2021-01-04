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
    :account_email,
    :account_name,
    :account_role,
    :account_created
  ]

  @subjects %{
    help_credit: "How can I get credit for an OLI course?",
    help_course_key: "Where do I find my course key?",
    help_charge: "My credit card was charged (multiple times, possibly) and I still cannot access my course",
    help_lbd: "The Learn By Doing or Did I Get This? Exercises don't work properly, or the text is cut off",
    help_server: "The server timed out or I received an unknown error",
    help_tech: "Technical support",
    help_course_content: "Course content",
    help_course_feedback: "Feedback about a course or OLI",
    help_other: "Other questions or comments"
  }

  def parse(%{"full_name" => full_name, "email" => email, "subject" => subject, "message" => message}) do
    help_content = %Oli.Help.HelpContent{
      full_name: full_name,
      email: email,
      subject: subject,
      message: message
    }
    {:ok, help_content}
  end

  def parse(_) do
    {:error, "incomplete help request"}
  end

  def get_subject(key) do
    Map.get(@subjects, String.to_existing_atom(key))
  end
end
