defmodule Mosaic.Emails do
  @moduledoc """
  Emails context
  """
  alias Mosaic.Emails.Email

  def get_email!(id) do
    Mosaic.repo().get!(Email, id)
  end

  def create_email(attrs) do
    %Email{}
    |> Email.changeset(attrs)
    |> Mosaic.repo().insert()
  end

  def update_email(%Ecto.Changeset{} = changeset) do
    changeset |> Mosaic.repo().update()
  end

  def update_email(id, attrs) do
    id
    |> get_email!()
    |> Email.changeset(attrs)
    |> update_email()
  end
end
