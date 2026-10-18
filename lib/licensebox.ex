defmodule Licensebox do
  @moduledoc """
  Native Linux application licensing. Returns `{:ok, value}` or
  `{:error, {code, detail}}`. Close each linked client explicitly.
  Hooks are trusted functions, never JSON identity overrides.
  """
  def start_link(product, keys, options \\ [], hooks \\ []) do
    :licensebox.start_link(product, keys, Map.new(options), Map.new(hooks))
  end
  def close(client), do: :licensebox.close(client)
  def lease(client), do: :licensebox.lease(client)
  def require_module(client, name), do: :licensebox.require_module(client, name)
  def status(client), do: :licensebox.status(client)
  def sign_in(client, timeout \\ 0), do: :licensebox.sign_in(client, timeout)
  def logout(client), do: :licensebox.logout(client)
  def modules(client), do: :licensebox.modules(client)
  def requests(client), do: :licensebox.requests(client)
  def request_access(client, modules, note \\ ""), do: :licensebox.request_access(client, modules, note)
  def access_link(client), do: :licensebox.access_link(client)
  def record(client, command, success, elapsed), do: :licensebox.record(client, command, success, elapsed)
  def derive_binding(product, source, raw), do: :licensebox.derive_binding(product, source, raw)
  def native_binding(product), do: :licensebox.native_binding(product)
  def verify_lease(token, product, keys, now), do: :licensebox.verify_lease(token, product, keys, now)
end
