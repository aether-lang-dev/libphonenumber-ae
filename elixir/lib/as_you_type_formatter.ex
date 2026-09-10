defmodule PhonenumberAe.AsYouTypeFormatter do
  @moduledoc """
  Formats a number as it is typed, digit by digit.

  The formatter state is a caller-owned string threaded through the shared NIF.
  `input_digit/2` returns a `{formatter, formatted_so_far}` pair so the struct
  stays immutable.

      f = PhonenumberAe.AsYouTypeFormatter.new("US")
      {_f, out} = Enum.reduce("2015550123" |> String.graphemes(), {f, ""},
        fn c, {f, _} -> PhonenumberAe.AsYouTypeFormatter.input_digit(f, c) end)
      # out => "(201) 555-0123"
  """

  defstruct [:state]

  @type t :: %__MODULE__{state: binary()}

  @doc "A fresh formatter for a region."
  @spec new(iodata()) :: t()
  def new(region), do: %__MODULE__{state: :phonenumber_ae_nif.ayt_new(region)}

  @doc """
  Feed one character. Returns `{new_formatter, formatted_so_far}` — the old
  formatter's state is now stale.
  """
  @spec input_digit(t(), iodata()) :: {t(), binary()}
  def input_digit(%__MODULE__{state: state}, ch) do
    next = :phonenumber_ae_nif.ayt_input(state, ch)
    {%__MODULE__{state: next}, :phonenumber_ae_nif.ayt_result(next)}
  end

  @doc "The formatted-so-far string for this formatter."
  @spec result(t()) :: binary()
  def result(%__MODULE__{state: state}), do: :phonenumber_ae_nif.ayt_result(state)

  @doc "Reset the formatter, returning a cleared one for the same region."
  @spec clear(t()) :: t()
  def clear(%__MODULE__{state: state}),
    do: %__MODULE__{state: :phonenumber_ae_nif.ayt_clear(state)}
end
