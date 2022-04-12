defmodule CoursesPage do
  use Hound.Helpers

  def click_course(course_name) do
    click({:xpath, "//*[@class='card-title'][contains(text(), '#{course_name}')]"})
  end

  def click_lesson(lesson_name) do
    click({:link_text, lesson_name})
  end
end
