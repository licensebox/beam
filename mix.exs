defmodule Mix.Tasks.Compile.LicenseboxNative do
  use Mix.Task.Compiler
  def run(_) do
    {output, code} = System.cmd("make", ["priv/licensebox_nif.so"], stderr_to_stdout: true)
    Mix.shell().info(output)
    if code != 0, do: Mix.raise("native binding build failed")
    {:ok, []}
  end
end
defmodule Licensebox.MixProject do
  use Mix.Project
  def project do
    [app: :licensebox, version: "0.1.0", elixir: ">= 1.14.0", compilers: [:licensebox_native] ++ Mix.compilers(),
     description: "Native Licensebox application licensing SDK", source_url: "https://github.com/licensebox/beam",
     package: [licenses: ["MIT"], links: %{"Homepage" => "https://meshing.engineer"}, files: ["lib", "src", "c_src", "Makefile", "mix.exs", "LICENSE", "README.md"]]]
  end
  def application, do: [extra_applications: [:jiffy]]
end
