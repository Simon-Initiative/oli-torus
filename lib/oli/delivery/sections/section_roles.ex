defmodule Oli.Delivery.Sections.SectionRoles do

  @instructor %Oli.Delivery.Sections.SectionRole{
    id: 1,
    type: "instructor"
  }

  @student %Oli.Delivery.Sections.SectionRole{
    id: 2,
    type: "student"
  }

  def list(), do: [@instructor, @student]

  def get_by_id(1), do: @instructor
  def get_by_id(2), do: @student

  def get_by_type("instructor"), do: @instructor
  def get_by_type("student"), do: @student

end
