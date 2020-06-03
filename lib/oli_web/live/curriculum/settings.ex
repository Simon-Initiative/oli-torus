defmodule OliWeb.Curriculum.Settings do
  use Phoenix.LiveComponent

  alias Oli.Resources.ScoringStrategy

  def render(assigns) do

    a = assigns.page.max_attempts
    strategy = ScoringStrategy.get_type_by_id(assigns.page.scoring_strategy_id)

    ~L"""
    <div class="page-settings">
      <div>Type:</div>
      <select class="custom-select">
        <option <%= if @page.graded do "selected" else "" end %> value="Scored">Assessment</option>
        <option <%= if @page.graded do "" else "selected" end %> value="Unscored">Page</option>
      </select>

      <%= if @page.graded do %>
        <div>Number of Attempts:</div>
        <select class="custom-select">
          <option <%= if a == 0 do "selected" else "" end %> value="0">Unlimited</option>
          <option <%= if a == 1 do "selected" else "" end %> value="1">1</option>
          <option <%= if a == 2 do "selected" else "" end %> value="2">2</option>
          <option <%= if a == 3 do "selected" else "" end %> value="3">3</option>
          <option <%= if a == 4 do "selected" else "" end %> value="4">4</option>
          <option <%= if a == 5 do "selected" else "" end %> value="5">5</option>
          <option <%= if a == 6 do "selected" else "" end %> value="6">6</option>
          <option <%= if a == 7 do "selected" else "" end %> value="7">7</option>
          <option <%= if a == 8 do "selected" else "" end %> value="8">8</option>
          <option <%= if a == 9 do "selected" else "" end %> value="9">9</option>
          <option <%= if a == 10 do "selected" else "" end %> value="10">10</option>
        </select>

        <div>Scoring Strategy</div>
        <select class="custom-select">
          <option <%= if strategy == "average" do "selected" else "" end %> value="average">Average</option>
          <option <%= if strategy == "best" do "selected" else "" end %> value="best">Best</option>
          <option <%= if strategy == "most_recent" do "selected" else "" end %> value="most_recent">Most recent</option>
        </select>
      <% end %>
    </div>
    """
  end
end
