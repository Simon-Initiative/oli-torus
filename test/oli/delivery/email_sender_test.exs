defmodule Oli.Delivery.EmailSenderTest do
  use Oli.DataCase, async: false
  use Oban.Testing, repo: Oli.Repo

  alias Oli.Delivery.EmailSender
  alias Oli.Mailer.SendEmailWorker
  alias Oli.Repo

  setup do
    Repo.delete_all(Oban.Job)
    :ok
  end

  describe "deliver_text_emails/5" do
    test "returns the enqueued email count when scheduling succeeds" do
      assert {:ok, 2} =
               EmailSender.deliver_text_emails(
                 [" student1@example.edu ", "student2@example.edu", "student1@example.edu"],
                 "Subject line",
                 "Email body",
                 "instructor@example.edu",
                 "Instructor Example"
               )

      jobs = Repo.all(Oban.Job)
      assert length(jobs) == 2

      emails =
        jobs
        |> Enum.map(&SendEmailWorker.deserialize_email(&1.args["email"]))
        |> Enum.sort_by(fn email -> elem(List.first(email.to), 1) end)

      assert Enum.map(emails, & &1.to) == [
               [{"", "student1@example.edu"}],
               [{"", "student2@example.edu"}]
             ]

      assert Enum.all?(emails, fn email ->
               email.subject == "Subject line" and
                 email.text_body == "Email body" and
                 email.reply_to == {"Instructor Example", "instructor@example.edu"}
             end)
    end

    test "returns zero when there are no valid recipient emails" do
      assert {:ok, 0} =
               EmailSender.deliver_text_emails(
                 [nil, "", "   "],
                 "Subject line",
                 "Email body",
                 "instructor@example.edu",
                 "Instructor Example"
               )

      assert Repo.all(Oban.Job) == []
    end
  end
end
