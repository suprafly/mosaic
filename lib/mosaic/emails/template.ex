defmodule Mosaic.Emails.Template do
  use Ecto.Schema

  import Ecto.Changeset

  alias Mosaic.Emails.Template

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field :body, :string
  end

  @doc false
  def changeset(%Template{} = template, attrs) do
    template
    |> cast(attrs, [:body])
    |> validate_required([:body])
    |> validate_template()
  end

  @doc false
  def validate_template(changeset) do
    validate_change(changeset, :body, fn field, value ->
      case Solid.parse(value) do
        {:ok, _} -> []
        {:error, %Solid.TemplateError{reason: reason, line: {line, _}}} ->
          msg = "Reason: #{reason}, line: #{line}"
          [{field, msg}]
      end
    end)
  end
end
