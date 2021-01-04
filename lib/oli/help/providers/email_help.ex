defmodule Oli.Help.Providers.EmailHelp do
  @behaviour Oli.Help.Dispatcher

  alias Oli.Help.HelpContent

  @impl Oli.Help.Dispatcher
  def dispatch(%HelpContent{} = contents) do
    help_desk_email = System.get_env("HELP_DESK_EMAIL")
    email = Oli.Email.help_desk_email(
      contents.full_name,
      contents.email,
      help_desk_email,
      HelpContent.get_subject(contents.subject),
      :help_email,
      %{
        message: contents.message
      }
    )

    Oli.Mailer.deliver_now(email)
    {:ok, "email sent"}
  end

end
