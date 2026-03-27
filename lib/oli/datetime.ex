defmodule Oli.DateTime do
  @callback utc_now :: DateTime.t()
  @callback now!(String.t()) :: DateTime.t()

  @override_key :oli_datetime_override

  def utc_now() do
    get_override() || call_utc_now()
  end

  def now!(timezone) do
    get_override() || call_now(timezone)
  end

  def set_override(nil) do
    Process.delete(@override_key)
    nil
  end

  def set_override(%DateTime{} = datetime) do
    Process.put(@override_key, datetime)
  end

  def get_override do
    Process.get(@override_key)
  end

  defp call_utc_now do
    date_time().utc_now()
  rescue
    e ->
      if exception_module_name(e) == "Elixir.Mox.UnexpectedCallError" do
        DateTime.utc_now()
      else
        reraise e, __STACKTRACE__
      end
  end

  defp call_now(timezone) do
    date_time().now!(timezone)
  rescue
    e ->
      if exception_module_name(e) == "Elixir.Mox.UnexpectedCallError" do
        DateTime.shift_zone!(DateTime.utc_now(), timezone)
      else
        reraise e, __STACKTRACE__
      end
  end

  defp date_time(), do: Application.get_env(:oli, :date_time_module, DateTime)

  defp exception_module_name(%{__struct__: module}) when is_atom(module),
    do: Atom.to_string(module)

  defp exception_module_name(_), do: nil
end
