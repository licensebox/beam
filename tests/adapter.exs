r = :jiffy.decode(IO.read(:stdio, :eof), [:return_maps])
run = fn ->
  case r["op"] do
    "derive" -> Licensebox.derive_binding(r["product"], r["source"], r["raw_id"])
    "native" -> Licensebox.native_binding(r["product"])
    "verify" -> Licensebox.verify_lease(r["token"], r["product"], r["keys"], r["now"])
    op ->
      opts = [version: "conformance", server: r["server"], directory: r["directory"]]
      opts = if r["ca_bundle"], do: Keyword.put(opts, :ca_bundle, r["ca_bundle"]), else: opts
      {:ok, c} = Licensebox.start_link(r["product"], r["keys"], opts, [clock: fn -> r["now"] end, machine_binding: fn -> r["binding"] end, on_sign_in: fn _, _ -> :ok end])
      try do
        case op do
          "lease" -> Licensebox.lease(c)
          "status" -> Licensebox.status(c)
          "sign_in" -> Licensebox.sign_in(c, 3)
          "require" -> Licensebox.require_module(c, Map.get(r,"module","core"))
          "repeat" -> with {:ok, _} <- Licensebox.require_module(c,"core"), do: Licensebox.require_module(c,"core")
          "logout" -> Licensebox.logout(c)
          "modules" -> Licensebox.modules(c)
          "requests" -> Licensebox.requests(c)
          "request" -> Licensebox.request_access(c,["export"],"café – test")
          "access-link" -> Licensebox.access_link(c)
          "record" -> with {:ok, _} <- Licensebox.record(c,"export",true,0.125), do: Licensebox.record(c,"export",false,0.025)
        end
      after
        Licensebox.close(c)
      end
  end
end
answer = case run.() do
  {:ok, v} -> %{"ok" => true, "value" => v}
  {:error, {code, _}} -> %{"ok" => false, "error" => code}
end
IO.puts(:jiffy.encode(answer))
