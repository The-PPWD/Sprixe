defmodule Client.Render do
  use GenServer

  require Logger

  defstruct [:map, :local_player, :other_players, frame: 0]

  @field_of_view :math.pi() / 2
  @half_field_of_view @field_of_view / 2


  def start_link(_) do
    options = [name: __MODULE__]
    GenServer.start_link(__MODULE__, [], options)
  end


  def map(map) do
    GenServer.cast(__MODULE__, {:map, map})
  end


  def tick(players) do
    GenServer.cast(__MODULE__, {:tick, players})
  end


  def init(_) do
    {:ok, %Client.Render{}}
  end


  def handle_cast({:map, new_map}, %{map: old_map} = state) do
    Logger.info("Updating map from #{inspect(old_map)} to #{inspect(new_map)}.")
    state = %{state | map: new_map}
    {:noreply, state}
  end

  def handle_cast({:tick, new_players}, %{local_player: old_local_player, other_players: old_other_players, frame: frame} = state) do
    new_local_player = Enum.find(new_players, fn %{player_name: player_name} -> player_name === node() end)
    Logger.info("Updating local player from #{inspect(old_local_player)} to #{inspect(new_local_player)}.")

    new_other_players = List.delete(new_players, new_local_player)
    Logger.info("Updating other players from #{inspect(old_other_players)} to #{inspect(new_other_players)}.")

    state = %{state | local_player: new_local_player, other_players: new_other_players, frame: frame + 1}

    render(state)

    {:noreply, state}
  end


  def render(%{frame: frame} = state) do
    Logger.metadata(frame: frame)

    ExNcurses.clear()
    render_map(state)
#    render_players(state)
    ExNcurses.refresh()
  end


  def render_map(%{local_player: %{yaw: yaw}} = state) do
    # could be better to take first and last and divide by cols?
    angle_step = @field_of_view / ExNcurses.cols()
    first_angle = yaw + @half_field_of_view
    last_angle = yaw - @half_field_of_view

    angles = Stream.iterate(first_angle, &(&1 - angle_step)) |> Enum.take_while(&(&1 >= last_angle))

    # math right here?
    columns = Stream.iterate(0, &(&1 + 1)) |> Enum.take_while(&(&1 < length(angles)))

    Enum.zip(angles, columns) |> Enum.each(&render_screen_column(&1, state))
  end


  def render_screen_column({angle, column}, %{local_player: %{position: player_position}} = state) do
    {relative_ray_x, relative_ray_z} = ray_position = angle_to_position(angle)
    Logger.debug("Ray position: #{inspect(ray_position)}.")

    {x_direction, z_direction} = ray_directions = directions_from_position(ray_position)
    Logger.debug("Ray directions: #{inspect(ray_directions)}.")

    {partial_x, partial_z} = partials = partial_positions(player_position, ray_directions)
    Logger.debug("Partials: #{inspect(partials)}.")

    x_scalar = (1 + :math.pow(relative_ray_z / relative_ray_x, 2)) |> :math.sqrt()
    z_scalar = (1 + :math.pow(relative_ray_x / relative_ray_z, 2)) |> :math.sqrt()
    Logger.debug("Scalars: #{inspect({x_scalar, z_scalar})}.")

    collision_1 = cast_ray({relative_ray_x, relative_ray_z}, x_direction, x_scalar, partial_x, state)
    collision_2 = cast_ray({relative_ray_x, relative_ray_z}, z_direction, z_scalar, partial_z, state)

    Logger.debug("Collisions: #{inspect(collision_1)}, #{inspect(collision_2)}.")

    collision_position =
      Enum.filter([collision_1, collision_2], &(&1 !== nil))
      |> Enum.min(&minimum_position/2)

    distance = position_to_distance(collision_position) |> :math.ceil()

    screen_height = ExNcurses.lines()

    # TODO: Why does `ceil(screen_height / 2 - screen_height / distance)` not work?
    # TODO: Also, this code will break for distances < 1
    wall_top = ceil(screen_height / 2 - screen_height / (1 + distance))
    wall_bottom = ceil(screen_height / 2 + screen_height / (1 + distance))

    wall_top..wall_bottom |> Enum.each(&ExNcurses.mvaddstr(&1, column, "*"))
  end


  def cast_ray(position, direction, scalar, 0, state), do: cast_ray(position, direction, scalar, state)

  def cast_ray(position, direction, scalar, partial, state) do
    position = update_position(position, direction, scalar, partial)
    cast_ray(position, direction, scalar, state)
  end


  def cast_ray({relative_ray_x, relative_ray_z}, direction, scalar, %{local_player: %{position: {player_x, player_z}}} = state) do
    rounded_absolute_ray_position = {round(relative_ray_x + player_x), round(relative_ray_z + player_z)}
    rounded_relative_ray_position = {round(relative_ray_x), round(relative_ray_z)}

    Logger.debug("Relative ray x: #{relative_ray_x}.")
    Logger.debug("Relative ray z: #{relative_ray_z}.")

    Logger.debug("Casting ray #{inspect(rounded_absolute_ray_position)}.")

    case hit_wall(rounded_absolute_ray_position, state) do
      nil -> nil
      true -> rounded_relative_ray_position
      false ->
        rounded_relative_ray_position = update_position(rounded_relative_ray_position, direction, scalar)
        cast_ray(rounded_relative_ray_position, direction, scalar, state)
    end
  end


  def hit_wall({x, z}, _) when x < 0 or z < 0, do: nil

  def hit_wall({x, z}, %{map: map} = state) do
    Logger.debug("Checking if (#{x}, #{z}) hit a wall.")
    index = map_position_to_index({x, z}, state)

    case index === nil do
      true -> nil
      false -> Enum.at(map, index) === 1
    end
  end


  def map_position_to_index({x, z}, %{map: map}) do
    map_length = length(map)

    map_width = map_length |> :math.sqrt() |> trunc()
    index = map_width * floor(z) + floor(x)

    case index < map_length do
      true -> index
      false -> nil
    end
  end


  def angle_to_position(angle), do: {:math.sin(angle), :math.cos(angle)}


  def directions_from_position({x, z}),
       do: {x_direction_from_position(x), z_direction_from_position(z)}


  def x_direction_from_position(x) when x < 0, do: :east
  def x_direction_from_position(_), do: :west


  def z_direction_from_position(z) when z < 0, do: :south
  def z_direction_from_position(_), do: :north


  def partial_positions({x_position, z_position}, {x_direction, z_direction}),
       do: {partial_position(x_position, x_direction), partial_position(z_position, z_direction)}

  def partial_position(position, direction) when direction in [:west, :north], do: ceil(position) - position
  def partial_position(position, direction) when direction in [:east, :south], do: trunc(position) - position


  def minimum_position(position_a, position_b),
      do: position_to_distance(position_a) <= position_to_distance(position_b)


  def position_to_distance({x, z}), do: (:math.pow(x, 2) + :math.pow(z, 2)) |> :math.sqrt()


  def update_position({x, z}, direction, scalar, partial) when direction in [:north, :south],
      do: {x + partial * scalar, z + partial}

  def update_position({x, z}, direction, scalar, partial) when direction in [:east, :west],
      do: {x + partial, z + partial * scalar}

  def update_position({x, z}, :north, scalar), do: {x + scalar, z + 1}
  def update_position({x, z}, :south, scalar), do: {x + scalar, z - 1}
  def update_position({x, z}, :east, scalar), do: {x - 1, z + scalar}
  def update_position({x, z}, :west, scalar), do: {x + 1, z + scalar}
end
