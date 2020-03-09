defmodule Oli.Utils do
  def random_string(length) do
    alpha = ?a..?z |> Enum.to_list
    numeric = ?0..?9 |> Enum.to_list

    # FIXME: LTI validation doesn't seem to work with special characters like +
    # symbol = [?!, ?#, ?$, ?%, ?&, ?+] |> Enum.to_list
    # alphabet = alpha ++ numeric ++ symbol

    alphabet = alpha ++ numeric
    IO.inspect(alphabet)
    for _ <- 1..length, into: "", do: << Enum.random(alphabet) >>
  end
end
