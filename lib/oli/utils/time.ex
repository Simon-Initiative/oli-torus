defmodule Oli.Utils.Time do

  def now() do
    {:ok, datetime} = DateTime.now("Etc/UTC")
    datetime
  end

end
