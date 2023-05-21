defmodule Server.Application do
  use Application

  require Logger

  @impl true
  def start(_, _) do
    Logger.info("#{__MODULE__} starting.")

    children = [
      Server.Connection,
      {Registry, keys: :unique, name: Server.PlayerRegistry},
      Server.PlayerSupervisor
    ]

    options = [strategy: :one_for_one]
    Supervisor.start_link(children, options)
  end

  @impl true
  def stop(_) do
    Logger.info("#{__MODULE__} stopping.")
  end
end
