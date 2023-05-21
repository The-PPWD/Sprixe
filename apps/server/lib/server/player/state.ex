defmodule Server.Player.State do
  use Agent, restart: :transient, significant: true

  @yaw_step 1 / :math.pi()
  #@full_circle :math.tau()
  @full_circle :math.pi() * 2

  defstruct [:player_name, x: 1, z: 1, yaw: 0]

  def start_link(player_name) do
    state = %Server.Player.State{player_name: player_name}
    Agent.start_link(fn -> state end)
  end

  def input(pid, action) do
    function = Function.capture(__MODULE__, action, 1)
    Agent.update(pid, function)
  end

  def move_forward(%{z: z} = state) do
    %{state | z: z + 0.1}
  end

  def move_backward(%{z: z} = state) do
    %{state | z: z - 0.1}
  end

  def move_left(%{x: x} = state) do
    %{state | x: x - 0.1}
  end

  def move_right(%{x: x} = state) do
    %{state | x: x + 0.1}
  end

  def turn_left(%{yaw: yaw} = state) do
    normalized_yaw = :math.fmod(yaw - @yaw_step, @full_circle)
    %{state | yaw: normalized_yaw}
  end

  def turn_right(%{yaw: yaw} = state) do
    normalized_yaw = :math.fmod(yaw + @yaw_step, @full_circle)
    %{state | yaw: normalized_yaw}
  end
end
