defmodule PhonenumberAe.ParsedNumber do
  @moduledoc """
  A parsed phone number. Wraps the caller-owned parsed-number string the ABI
  returns; its fields are read on demand through the shared NIF.
  """

  defstruct [:pn]

  @type t :: %__MODULE__{pn: binary()}

  @doc false
  def new(pn), do: %__MODULE__{pn: pn}

  @doc "The parse error, or \"\" if the parse succeeded."
  @spec error(t()) :: binary()
  def error(%__MODULE__{pn: pn}), do: :phonenumber_ae_nif.pn_error(pn)

  @doc "The region the number was parsed for."
  @spec region(t()) :: binary()
  def region(%__MODULE__{pn: pn}), do: :phonenumber_ae_nif.pn_region(pn)

  @doc "The country calling code."
  @spec country_code(t()) :: binary()
  def country_code(%__MODULE__{pn: pn}), do: :phonenumber_ae_nif.pn_country_code(pn)

  @doc "The national number."
  @spec national_number(t()) :: binary()
  def national_number(%__MODULE__{pn: pn}), do: :phonenumber_ae_nif.pn_national_number(pn)

  @doc "The extension, or \"\"."
  @spec extension(t()) :: binary()
  def extension(%__MODULE__{pn: pn}), do: :phonenumber_ae_nif.pn_extension(pn)

  @doc "True if the number carried a significant leading zero."
  @spec italian_leading_zero?(t()) :: boolean()
  def italian_leading_zero?(%__MODULE__{pn: pn}),
    do: :phonenumber_ae_nif.pn_italian_leading_zero(pn) != 0

  @doc "The `t:PhonenumberAe.country_code_source/0` for how the cc was found."
  @spec source(t()) :: PhonenumberAe.country_code_source()
  def source(%__MODULE__{pn: pn}), do: source_atom(:phonenumber_ae_nif.pn_source(pn))

  @doc "The region code the number belongs to."
  @spec region_code(t()) :: binary()
  def region_code(%__MODULE__{pn: pn}), do: :phonenumber_ae_nif.region_code_for_number(pn)

  @doc "The national significant number."
  @spec national_significant_number(t()) :: binary()
  def national_significant_number(%__MODULE__{pn: pn}),
    do: :phonenumber_ae_nif.national_significant_number(pn)

  @doc "The length of the national destination code."
  @spec length_of_ndc(t()) :: integer()
  def length_of_ndc(%__MODULE__{pn: pn}), do: :phonenumber_ae_nif.length_of_ndc(pn)

  @doc "The length of the area code."
  @spec length_of_area_code(t()) :: integer()
  def length_of_area_code(%__MODULE__{pn: pn}), do: :phonenumber_ae_nif.length_of_area_code(pn)

  @doc "True if the number is geographical (tied to a place)."
  @spec is_geographical?(t()) :: boolean()
  def is_geographical?(%__MODULE__{pn: pn}), do: :phonenumber_ae_nif.is_geographical(pn) != 0

  # CountryCodeSource codes -> atoms.
  defp source_atom(1), do: :from_number_with_plus
  defp source_atom(5), do: :from_number_with_idd
  defp source_atom(10), do: :from_number_without_plus
  defp source_atom(20), do: :from_default_country
  defp source_atom(_), do: :unspecified
end

