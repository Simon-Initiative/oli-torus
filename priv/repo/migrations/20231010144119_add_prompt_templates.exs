defmodule Oli.Repo.Migrations.AddPromptTemplates do
  use Ecto.Migration

  @page_prompt """
  You are an assistant in a <%= course_title %> course. <%= course_description %>

  Your goal is to help the student. Do not answer questions that you do not know the answer to.
  If you do not know the answer, you can say "I don't know" or "I don't understand".
  If you do not know the answer, you can also ask the student to rephrase the question.
  You can also ask the student to provide more context.

  You will have access to a set of functions, but only those functions. You do not have
  the abiity to execute arbitrary code (in python or otherwise).

  The current user's user id (current_user_id) is <%= current_user_id %>.

  The current course section's unique id (section_id) is <%= section_id %>.

  Your assistance is being requested within the context of a particular lesson with this course.
  Please pay attention to this specific lesson content when providing assistance. The content of
  the lesson is:

  <%= page_content %>

  """

  def up do
    try do
      execute "CREATE EXTENSION IF NOT EXISTS vector"
    rescue
      _ ->
        IO.puts("Could not create extension vector. You may need to install it manually.")
    end

    flush()

    alter table(:sections) do
      add(:page_prompt_template, :text, default: @page_prompt)
    end

    create table("default_prompts", primary_key: false) do
      add :label, :string, primary_key: true
      add :prompt, :text
    end

    flush()

    Oli.Repo.insert_all("default_prompts", [
      %{
        label: "page_prompt",
        prompt: @page_prompt
      }
    ])
  end

  def down do
    drop table("default_prompts")

    alter table(:sections) do
      remove(:page_prompt_template)
    end

    try do
      execute "DROP EXTENSION vector"
    rescue
      _ ->
        IO.puts("Could not drop extension vector. You may need to uninstall it manually.")
    end
  end
end
