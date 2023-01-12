defmodule OliWeb.AccountsCache do
  @cache_key :cache_account

  def get_cache_key(),
    do: @cache_key

  def get(key),
    do: Cachex.get(@cache_key, key)

  def put(key, value) do
    Cachex.put(
      @cache_key,
      key,
      value,
      ttl: :timer.hours(24)
    )
  end

  def update(key, value),
    do: Cachex.update(@cache_key, key, value)

  def delete(key),
    do: Cachex.del(@cache_key, key)
end
