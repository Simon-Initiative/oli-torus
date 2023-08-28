defmodule Oli.Broadway do
  use Broadway

  def start_link(_opts) do
    Broadway.start_link(MyBroadway,
      name: Oli.Analytics.Pipeline,
      producer: [
        module: {Broadway.Producers.List, []},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: 2]
      ]
    )
  end

end
