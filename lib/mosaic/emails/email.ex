defmodule Mosaic.Emails.Email do
  use Ecto.Schema

  import Ecto.Changeset

  alias Mosaic.Emails.Email
  alias Mosaic.Emails.Template

  @derive Jason.Encoder
  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "mosaic_emails" do
    field :from, :string
    field :reply_to, :string

    # `:to` can be empty because this template could be used on a form,
    # in which case the addresses will come from the data by way of `:to_keys` later on.
    field :to, {:array, :string}, default: []
    field :to_csv, :string, virtual: true

    # These are keys that are used to access fields on the incoming data
    # where the email addresses are stored.
    field :to_keys, {:array, :string}, default: []
    field :to_keys_csv, :string, virtual: true

    field :cc, {:array, :string}, default: []
    field :cc_csv, :string, virtual: true

    field :bcc, {:array, :string}, default: []
    field :bcc_csv, :string, virtual: true

    field :subject, :string

    # Body will be used if the template is disabled
    field :body, :string

    field :use_template, :boolean, default: false

    embeds_one :template, Template, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(%Email{} = email, attrs) do
    valid_attrs = [
      :from,
      :reply_to,
      # :to,
      :to_csv,
      # :to_keys,
      :to_keys_csv,
      # :cc,
      :cc_csv,
      # :bcc,
      :bcc_csv,
      :subject,
      :body,
      :use_template
    ]

    email
    |> cast(attrs, valid_attrs)
    |> validate_email(:from)
    |> validate_email(:reply_to)
    # These `:*_csv` fields are the string version. They are virtual fields and are used
    # to set from a LV form-level.
    |> validate_email_list({:to_csv, :to})
    |> validate_email_list({:to_keys_csv, :to_keys}, false)
    |> validate_email_list({:cc_csv, :cc})
    |> validate_email_list({:bcc_csv, :bcc})
    |> validate_body_or_template_and_cast()
    |> validate_required([:from, :reply_to, :subject])
    |> validate_required_inclusion([:to, :to_keys])
    |> validate_length(:subject, min: 5)
  end

  @doc false
  def change(%Email{} = email, attrs \\ %{}) do
    email
    |> cast(attrs, [])
    |> add_virtual_fields()
  end

  def split_csv_string(nil), do: []

  def split_csv_string(csv_str) do
    csv_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(is_nil(&1) or String.length(&1) == 0))
  end

  def add_virtual_fields(changeset, opts \\ []) do
    # this should be used when generating the struct, not when creating a changeset
    pairs = [
      {:to, :to_csv},
      {:to_keys, :to_keys_csv},
      {:cc, :cc_csv},
      {:bcc, :bcc_csv}
    ]

    only = Keyword.get(opts, :only, []) |> List.wrap()

    pairs =
      if Enum.empty?(only) do
        pairs
      else
        Enum.filter(pairs, fn {_, k} -> k in only end)
      end

    Enum.reduce(pairs, changeset, &split_and_add/2)
  end

  def format_to_keys(%Email{} = email) do
    format_to_keys(email.to_keys)
  end

  def format_to_keys(to_keys) when is_list(to_keys) do
    to_keys |> Enum.map(&"{{ #{&1} }}") |> Enum.join(" ")
  end

  defp split_and_add({from_key, to_key}, changeset) do
    case get_field(changeset, from_key) do
      nil ->
        changeset

      [] ->
        put_change(changeset, to_key, "")

      fields ->
        put_change(changeset, to_key, Enum.join(fields, ", "))
    end
  end

  defp validate_email(changeset, field) do
    changeset
    |> validate_format(field, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(field, max: 160)
  end

  defp valid_email?(email) do
    match? = Regex.match?(~r/^[^\s]+@[^\s]+$/, email)
    len? = String.length(email) <= 160
    match? and len?
  end

  defp validate_email_list(changeset, {virtual_field, form_field}, validate? \\ true) do
    mapped_values =
      changeset
      |> get_change(virtual_field)
      |> split_csv_string()
      |> Enum.map(&{&1, valid_email?(&1)})

    changeset =
      if validate? do
        validate_change(changeset, virtual_field, fn field, _value ->
          if Enum.all?(mapped_values, &elem(&1, 1)) do
            []
          else
            mapped_values
            |> Enum.reject(&elem(&1, 1))
            |> Enum.map(&{field, "#{elem(&1, 0)} must have the @ sign and no spaces"})
          end
        end)
      else
        changeset
      end

    if changeset.valid? do
      value = Enum.map(mapped_values, &elem(&1, 0))
      put_change(changeset, form_field, value)
    else
      changeset
    end
  end

  defp validate_body_or_template_and_cast(changeset) do
    case get_field(changeset, :body) do
      nil ->
        changeset
        |> cast_embed(:template, required: true)
        # If there is no body but there is a template, set use_template to true
        |> put_change(:use_template, true)
      _body ->
        changeset
        |> validate_required([:body])
        |> cast_embed(:template)
    end
  end

  defp validate_required_inclusion(changeset, fields) do
    if changeset.valid? do
      if Enum.any?(fields, &not_nil?(changeset, &1)) do
        changeset
      else
        add_error(changeset, hd(fields), "One of these fields must be present: #{inspect fields}")
      end
    else
      changeset
    end
  end

  defp not_nil?(changeset, field) do
    changeset
    |> get_field(field)
    |> not_nil?()
  end

  defp not_nil?(value) do
    not is_nil(value)
  end
end
