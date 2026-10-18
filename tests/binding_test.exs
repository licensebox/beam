ExUnit.start()
defmodule LicenseboxTest do
  use ExUnit.Case
  test "native identity and malformed lease" do
    assert {:ok, "m1:" <> _} = Licensebox.derive_binding("demo","linux-machine-id","12345678123456789abc1234567890ab\0")
    assert {:error, {"malformed", _}} = Licensebox.verify_lease("bad","demo",%{},0)
  end
end
