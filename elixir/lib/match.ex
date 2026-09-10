defmodule PhonenumberAe.Match do
  @moduledoc "A phone number found in free text: `start`, `end` offsets and `raw` text."

  defstruct [:start, :end, :raw]

  @type t :: %__MODULE__{start: non_neg_integer(), end: non_neg_integer(), raw: binary()}
end

