defmodule PhonenumberAe.MixProject do
  use Mix.Project

  @moduledoc """
  Build manifest for the Elixir surface over the canonical BEAM NIF.

  NOTE what is NOT here: no `make`, no `elixir_make`, no `c_src`. This project
  compiles nothing native. The NIF is built once by `erlang/.build.ae` and this
  project loads that already-compiled artifact — see `test/test_helper.exs`.

  That is deliberate. `elixir_make` is the usual way an Elixir package ships a
  NIF, but using it here would mean a SECOND copy of the C and a second `.so`,
  which is exactly what this monorepo's one-engine rule forbids.
  """

  def project do
    [
      app: :phonenumber_ae,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "Validate and format international phone numbers — Elixir surface over the shared Aether engine",
      package: package(),
      # No network access is needed to build or test this project; the dep list
      # below is empty on purpose so `mix test` runs offline.
      docs: [main: "PhonenumberAe"]
    ]
  end

  # Hex package metadata. `mix hex.build` (used by elixir/.dist.ae to produce the
  # distribution .tar) refuses to build without `licenses` and `links`, so they
  # live here. The NIF is built once by erlang/.build.ae and loaded at runtime —
  # this package ships only the Elixir surface, no C and no second .so — so no
  # priv/ files are listed.
  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"Source" => "https://github.com/google/libphonenumber"}
    ]
  end

  def application do
    # No `mod:` — there is no supervision tree. The engine is a pure stateless
    # transform, not a named process.
    #
    # `:phonenumber_ae_nif` is deliberately NOT listed in `extra_applications`:
    # Mix would then insist on finding it as a managed dependency, but it is an
    # OTP app built outside Mix and placed on the code path at runtime. The
    # modules load fine from the code path without an application start.
    [extra_applications: [:logger]]
  end

  defp deps do
    # Intentionally empty. The binding needs nothing but the NIF, and an empty
    # dep list is what keeps `mix test` runnable with no hex.pm access.
    []
  end
end
