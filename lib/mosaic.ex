defmodule Mosaic do
  @moduledoc """
  An email framework.
  """
  import Swoosh.Email

  @behaviour Mosaic.Behaviour

  def email_context do
    Application.get_env(:mosaic, :email_context)
  end

  def repo do
    Application.get_env(:mosaic, :repo)
  end

  def mailer do
    Application.get_env(:mosaic, :mailer)
  end

  @doc """
  Takes a non-nested map and splits its keys and values into an object with nested lists.

  ## Example
      data = %{
        date: "X",
        country: "USA",
        city: "Honolulu",
        attrs: %{"first_name" => "Jon", "last_name" => "Chain"}
      }

      parse_data(data, flatten: :attrs)

      %{
        "city" => "Honolulu",
        "country" => "USA",
        "date" => "X",
        "attrs" => [["first_name", "Jon"], ["last_name", "Chain"]]
      }
  """
  def parse_data(data, opts \\ []) when is_map(data) do
    data = Map.new(data, fn {k, v} -> {to_string(k), v} end)
    flatten_maps = Keyword.get(opts, :flatten, []) |> List.wrap()
    flattened = Enum.reduce(flatten_maps, %{}, fn
      {from_key, to_key}, acc -> Map.put(acc, "#{to_key}", flatten_map(data["#{from_key}"]))
      key, acc -> Map.put(acc, "#{key}", flatten_map(data["#{key}"]))
    end)
    Map.merge(data, flattened)
  end

  defp flatten_map(data) do
    Enum.reduce(data, [],
      fn {k, v}, acc ->
        acc ++ [[k, v]]
    end)
  end

  @doc """
  Renders a template with a map of data.

  ## Example

      data = %{date: NaiveDateTime.local_now(), country: "USA", city: "Honolulu", attrs: %{"first_name" => "Jon", "last_name" => "Chain"}}
      Mosaic.default_template() |> Mosaic.render(attrs, flatten: :attrs)
      {:ok, "Submission date: 2024-09-26 15:38:21\\n\\nfirst_name: Jon\\nlast_name: Chain\\n\\nCountry: USA\\nCity: Honolulu"}
  """
  def render(template, data, opts \\ []) do
    with {:ok, parsed_template} <- Solid.parse(template),
         data = parse_data(data, opts),
         {:ok, result} <- Solid.render(parsed_template, data) do

      {:ok,
        result
        |> to_string()
        |> String.trim()}
    end
  end

  def render!(template, data, opts \\ []) do
    with parsed_template <- Solid.parse!(template),
         data = parse_data(data, opts),
         result <- Solid.render!(parsed_template, data) do
      result
      |> to_string()
      |> String.trim()
    end
  end

  @doc """

  ## Example

      data = %{
        date: NaiveDateTime.local_now(),
        country: "USA",
        city: "Honolulu",
        attrs: %{
          "first_name" => "Jon",
          "last_name" => "Chain",
          "email" => "j.chain@gmail.com"
          }
        }

      attrs = %{
        to: [],
        to_keys: [],
        from: "",
        subject: "",
        template: Mosaic.default_template()
      }

  ## Available `opts`
  - `:flatten` - a key or list of keys to flatten. Most useful for iteration in templates.
  - `:body` - determines what type of email to send, `:text` or `:html` (defaults to `:text`)
  """
  def send_email(email, data, opts \\ []) do
    {:ok, body} =
      if email.use_template do
        Mosaic.render(email.template.body, data, opts)
      else
        {:ok, email.body}
      end

    to_addresses = get_to_addresses(email, data)

    with false <- Enum.empty?(to_addresses) do
      deliver(email, body, to_addresses, opts)
    else
      _ ->
        {:error, "No mailto addresses specified"}
    end
  end

  defp deliver(email, body, to_addresses, opts) do
    # These values need to be formatted as a list of tuples: [{"Name", "Email"}]
    cc = Enum.map(email.cc, &{"", &1})
    bcc = Enum.map(email.bcc, &{"", &1})
    body_type = Keyword.get(opts, :body, :text)

    draft =
      new()
      |> to(to_addresses)
      |> from(email.from)
      |> reply_to(email.reply_to || email.from)
      |> subject(email.subject)
      |> cc(cc)
      |> bcc(bcc)
      |> add_body(body, body_type)

    with {:ok, _metadata} <- mailer().deliver(draft) do
      {:ok, email}
    end
  end

  defp add_body(email, body, :text) do
    text_body(email, body)
  end

  defp add_body(email, body, :html) do
    html_body(email, body)
  end

  @impl Mosaic.Behaviour
  def get_to_addresses(email, data) do
    email_context_module = email_context()
    if is_nil(email_context_module) do
      from_keys =
        email.to_keys
        |> Enum.map(fn k -> Map.get(data, k) end)
        |> Enum.reject(&is_nil/1)

      email.to ++ from_keys
    else
      email_context_module.get_to_addresses(email, data)
    end
  end
end

