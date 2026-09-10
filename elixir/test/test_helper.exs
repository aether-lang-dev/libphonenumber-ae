# Put the canonical BEAM NIF on the code path before any test runs.
#
# THE WRINKLE: `erl`, `escript` and `gleam` all honour $ERL_LIBS, so the Erlang
# and Gleam bindings find the app built by erlang/.build.ae for free. **Mix does
# not.** It builds its own code path from `deps/` and `_build/`, and an OTP app
# that Mix did not build is simply invisible to it.
#
# So elixir/.tests.ae exports $LIBPHONENUMBER_AE_BEAM_APP (the erlang_app
# artifact from the erlang/.build.ae node) and we append its ebin/ here. This is
# the whole reason there is no C source in elixir/: we load the SAME compiled
# phonenumber_ae_nif.beam and the SAME priv/phonenumber_ae_nif.so that the
# Erlang binding uses, rather than building a second copy.

case System.get_env("LIBPHONENUMBER_AE_BEAM_APP") do
  nil ->
    # Fall back to the in-tree location so `mix test` works by hand after a
    # plain `aeb erlang/.build.ae`.
    default = Path.expand("../../erlang/_build/phonenumber_ae_nif", __DIR__)

    if File.dir?(Path.join(default, "ebin")) do
      Code.append_path(Path.join(default, "ebin"))
    else
      IO.puts(:stderr, """
      phonenumber_ae: cannot find the NIF application.

      Build it first:
          aeb erlang/.build.ae
      or point $LIBPHONENUMBER_AE_BEAM_APP at the built app directory
      (the one containing ebin/ and priv/).
      """)

      System.halt(1)
    end

  app ->
    ebin = Path.join(app, "ebin")

    unless File.dir?(ebin) do
      IO.puts(:stderr, "phonenumber_ae: $LIBPHONENUMBER_AE_BEAM_APP=#{app} has no ebin/")
      System.halt(1)
    end

    Code.append_path(ebin)
end

# Load the NIF module now rather than at first use, so a load failure is
# reported here — with the engine path in the message — instead of surfacing as
# a confusing :nif_error deep inside a test.
case Code.ensure_loaded(:phonenumber_ae_nif) do
  {:module, _} ->
    :ok

  {:error, reason} ->
    IO.puts(:stderr, """
    phonenumber_ae: could not load :phonenumber_ae_nif (#{inspect(reason)}).

    The NIF dlopens the engine; set $LIBPHONENUMBER_AE_LIB to the absolute path
    of libphonenumber_ae.so if it is not beside the NIF in priv/.
    """)

    System.halt(1)
end

ExUnit.start()
