defmodule Mosaic.Mailer do
  use Swoosh.Mailer, otp_app: Application.get_env(:mosaic, :otp_app)
end
