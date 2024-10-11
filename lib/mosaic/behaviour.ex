defmodule Mosaic.Behaviour do
  @moduledoc """
  Defines callbacks that allow customization of functionality/
  """
  @callback get_to_addresses(email :: Mosaic.Email.t(), data :: map()) :: list(String.t)
end

