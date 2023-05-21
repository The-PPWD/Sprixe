defmodule Client.MixProject do
  use Mix.Project

  def project do
    [
      app: :client,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15-dev",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :logger_file_backend],
      mod: {Client.Application, []}
    ]
  end

  defp deps do
    [
      {:logger_file_backend, "~> 0.0.13"},
      {:ex_ncurses, "~> 0.3.1"}
    ]
  end
end
