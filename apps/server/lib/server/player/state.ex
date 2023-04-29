defmodule Server.Player.State do
  use Agent, restart: :transient, significant: true

  defstruct [:player_name, y: 0, x: 0]

  def start_link(player_name) do
    state = %Server.Player.State{player_name: player_name}
    Agent.start_link(fn -> state end)
  end

  def shutdown(pid, reason) do
    Agent.stop(pid, {:shutdown, reason})
  end

  def move(pid, direction) do
    action =
      case direction do
        :up -> & %{&1 | y: &1.y - 1}
        :down -> & %{&1 | y: &1.y + 1}
        :left -> & %{&1 | x: &1.x - 1}
        :right -> & %{&1 | x: &1.x + 1}
      end

    Agent.update(pid, action)
  end
end
