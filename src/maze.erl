-module(maze).

-export([
    generate_maze/1,
    remove_item/3,
    is_empty/3,
    is_wall/3,
    is_door/3,
    is_stairs/3,
    is_item/3
]).

-include("board.hrl").

-define(MazeComplexity, 10).
-define(MaxRoomWidth, 30).
-define(MinRoomWidth, 3).
-define(MaxRoomHeight, 10).
-define(MinRoomHeight, 3).
-define(MaxCorridorSegmentCount, 10).
-define(MaxCorridorSegmentLength, 10).
-define(ReciprocalDeadEnd, 5).

generate_maze(IsLastLevel) ->
    FirstRoom = [generate_room()],
    generate_maze(IsLastLevel, FirstRoom, ?MazeComplexity).

generate_maze(false, Maze, 0) ->
    [generate_stairs(Maze)] ++ Maze;
generate_maze(true, Maze, 0) ->
    [generate_treasure(Maze)] ++ Maze;
generate_maze(IsLastLevel, Maze, Trials) ->
    generate_maze(IsLastLevel, generate_door(Maze) ++ Maze, Trials - 1).

generate_stairs(Maze) ->
    {X, Y} = board:generate_point(),
    
    case maze:is_empty(Maze, X, Y) andalso
        not maze:is_door(Maze, X, Y) of
        true ->
            {stairs, {X, Y}};
        false ->
            generate_stairs(Maze)
    end.

generate_treasure(Maze) ->
    {X, Y} = board:generate_point(),
    
    case maze:is_empty(Maze, X, Y) andalso
        not maze:is_door(Maze, X, Y) of
        true ->
            {item, {X, Y}, treasure};
        false ->
            generate_treasure(Maze)
    end.

generate_room_dimensions() -> {
    ?MinRoomWidth + rand:uniform(?MaxRoomWidth - ?MinRoomWidth),
    ?MinRoomHeight + rand:uniform(?MaxRoomHeight - ?MinRoomHeight)
}.

generate_room() ->
    {Width, Height} = generate_room_dimensions(),

    X = rand:uniform(?BoardWidth - Width),
    Y = rand:uniform(?BoardHeight - Height),

    {room, {{X, Y}, {X + Width - 1, Y + Height - 1}}}.

generate_door(Maze) ->
    {X, Y} = board:generate_point(),
    
    case is_wall(Maze, X, Y) andalso
        not is_empty(Maze, X, Y) andalso
        not is_corner(Maze, X, Y) andalso
        not is_edge(X, Y) of
        true ->
            IsVert = rand:uniform(2) == 1,
            {DeltaX, DeltaY} = util:generate_delta(IsVert),
            {NewX, NewY} = {X + DeltaX, Y + DeltaY},
            
            case is_wall(Maze, NewX, NewY) orelse
                is_door(Maze, NewX, NewY) orelse
                is_corner(Maze, NewX, NewY) orelse
                is_empty(Maze, NewX, NewY) of
                true ->
                    generate_door(Maze);
                false ->
                    Corridor = generate_corridor(Maze, NewX, NewY, DeltaX, DeltaY),
                    case length(Corridor) of
                        0 ->
                            generate_door(Maze);
                        _ ->
                            Corridor ++ [{door, {X, Y}}]
                    end
            end;
        false ->
            generate_door(Maze)
    end.
    
generate_corridor(Maze, X, Y, DeltaX, DeltaY) ->
    SegmentCount = rand:uniform(?MaxCorridorSegmentCount),
    generate_corridor(Maze, X, Y, DeltaX, DeltaY, SegmentCount).

generate_corridor(Maze, X, Y, DeltaX, DeltaY, 0) ->
    case rand:uniform(?ReciprocalDeadEnd) of
        1 ->
            [];
        _ ->
            DoorX = X + DeltaX,
            DoorY = Y + DeltaY,
    
            {RoomWidth, RoomHeight} = generate_room_dimensions(),
            RoomCoords = case DeltaX of
                0 ->
                    %% Careful not to put the door in the room's corner:
                    RoomX1 = X - RoomWidth + 1 + rand:uniform(RoomWidth - 2),
                    RoomX2 = RoomX1 + RoomWidth,
                    case DeltaY of
                        1 ->
                            {{RoomX1, DoorY - RoomHeight}, {RoomX2, DoorY}};
                        -1 ->
                            {{RoomX1, DoorY}, {RoomX2, DoorY + RoomHeight}}
                    end;
                _ ->
                    %% Careful not to put the door in the room's corner:
                    RoomY1 = Y - RoomHeight + 1 + rand:uniform(RoomHeight - 2),
                    RoomY2 = RoomY1 + RoomHeight,
                    case DeltaX of
                        1 ->
                            {{DoorX, RoomY1}, {DoorX + RoomWidth, RoomY2}};
                        -1 ->
                            {{DoorX - RoomWidth, RoomY1}, {DoorX, RoomY2}}
                    end
            end,
            
            Room = {room, RoomCoords},
            
            case is_outside(Room) orelse room_overlaps(Maze, Room) of
                true ->
                    generate_corridor(Maze, X, Y, DeltaX, DeltaY, 0);
                false ->
                    [{door, {DoorX, DoorY}}, {room, RoomCoords}]
            end
    end;
generate_corridor(Maze, X, Y, DeltaX, DeltaY, SegmentCount) ->
    SegmentLength = rand:uniform(?MaxCorridorSegmentLength),
    EndX = min(max(X + SegmentLength * DeltaX, 1), ?BoardWidth),
    EndY = min(max(Y + SegmentLength * DeltaY, 1), ?BoardHeight),
    
    Segment = case X == EndX andalso Y == EndY of
        true ->
            %% Can't go in that direction;
            %% try changing direction to a perpendicular one.
            [];
        false ->
            %% Make sure the order of coordinates is from lower to higher
            %% so that comparisons for inclusion testing are easier:
            case DeltaX + DeltaY of
                1 ->
                    {corridor, {{X, Y}, {EndX, EndY}}};
                -1 ->
                    {corridor, {{EndX, EndY}, {X, Y}}}
            end
    end,
    
    DeltaChange = case rand:uniform(2) of
        1 ->
            1;
        2 ->
            -1
    end,

    case (Segment == []) orelse overlaps_rooms(Maze, Segment) of
        true ->
            generate_corridor(Maze, X, Y, DeltaX * DeltaChange, DeltaY * DeltaChange, SegmentCount - 1);
        false ->
            %% DeltaX/Y are substituted intentionally to switch direction to a perpendicular one:
            [Segment] ++ generate_corridor([Segment] ++ Maze, EndX, EndY, DeltaY * DeltaChange, DeltaX * DeltaChange, SegmentCount - 1)
    end.

remove_item(Maze, X, Y) ->
    remove_item(Maze, X, Y, {undefined, []}).

remove_item([{item, {PosX, PosY}, Item} | T], PosX, PosY, {undefined, NewMaze}) ->
    {Item, T ++ NewMaze};
remove_item([H | T], PosX, PosY, {undefined, NewMaze}) ->
    remove_item(T, PosX, PosY, {undefined, [H] ++ NewMaze});
remove_item([], _X, _Y, Result) ->
    Result.

is_empty([{room, {{X1, Y1}, {X2, Y2}}} | _T], PosX, PosY) when
    X1 < PosX, Y1 < PosY, X2 > PosX, Y2 > PosY ->
    true;
is_empty([{door, {PosX, PosY}} | _T], PosX, PosY) ->
    true;
is_empty([{stairs, {PosX, PosY}} | _T], PosX, PosY) ->
    true;
is_empty([{item, {PosX, PosY}, _} | _T], PosX, PosY) ->
    true;
is_empty([{corridor, {{X1, Y1}, {X2, Y2}}} | _T], PosX, PosY) when
    X1 =< PosX, Y1 =< PosY, X2 >= PosX, Y2 >= PosY ->
    true;
is_empty([_H | T], PosX, PosY) ->
    is_empty(T, PosX, PosY);
is_empty([], _PosX, _PosY) ->
    false.

is_wall([{room, {{X1, Y1}, {X2, Y2}}} | _T] = Maze, PosX, PosY) when
    X1 == PosX orelse X2 == PosX, Y1 =< PosY, Y2 >= PosY;
    Y1 == PosY orelse Y2 == PosY, X1 =< PosX, X2 >= PosX ->
    not is_empty(Maze, PosX, PosY);
is_wall([_H | T], PosX, PosY) ->
    is_wall(T, PosX, PosY);
is_wall([], _PosX, _PosY) ->
    false.

is_corner([{room, {{X1, Y1}, {X2, Y2}}} | _T], PosX, PosY) when
    X1 == PosX, Y1 == PosY;
    X2 == PosX, Y1 == PosY;
    X1 == PosX, Y2 == PosY;
    X2 == PosX, Y2 == PosY ->
    true;
is_corner([_H | T], PosX, PosY) ->
    is_corner(T, PosX, PosY);
is_corner([], _PosX, _PosY) ->
    false.

is_door([{door, {PosX, PosY}} | _T], PosX, PosY) ->
    true;
is_door([_H | T], PosX, PosY) ->
    is_door(T, PosX, PosY);
is_door([], _PosX, _PosY) ->
    false.

is_stairs([{stairs, {PosX, PosY}} | _T], PosX, PosY) ->
    true;
is_stairs([_H | T], PosX, PosY) ->
    is_stairs(T, PosX, PosY);
is_stairs([], _PosX, _PosY) ->
    false.

is_item([{item, {PosX, PosY}, _} | _T], PosX, PosY) ->
    true;
is_item([_H | T], PosX, PosY) ->
    is_item(T, PosX, PosY);
is_item([], _PosX, _PosY) ->
    false.

is_edge(X, Y) when
    X == 1; Y == 1; X == ?BoardWidth; Y == ?BoardHeight ->
    true;
is_edge(_X, _Y) ->
    false.

is_outside(X, Y) when
    X < 1; Y < 1; X > ?BoardWidth; Y > ?BoardHeight ->
    true;
is_outside(_X, _Y) ->
    false.

is_outside({room, {{X1, Y1}, {X2, Y2}}}) ->
    is_outside(X1, Y1) orelse is_outside(X2, Y2).

overlaps({{X1, Y1}, {X2, Y2}}, {{X3, Y3}, {X4, Y4}}) ->
    not (max(X1, X2) < min(X3, X4) orelse
        min(X1, X2) > max(X3, X4) orelse
        max(Y1, Y2) < min(Y3, Y4) orelse
        min(Y1, Y2) > max(Y3, Y4)).

room_overlaps([{_, {{_X1, _Y1}, {_X2, _Y2}} = Coords1} | T], {room, Coords2} = Room) ->
    case overlaps(Coords1, Coords2) of
        false ->
            room_overlaps(T, Room);
        true ->
            true
    end;
room_overlaps([_H | T], Room) ->
    room_overlaps(T, Room);
room_overlaps([], _Room) ->
    false.

overlaps_rooms([{room, Coords1} | T], {corridor, Coords2} = Corridor) ->
    case overlaps(Coords1, Coords2) of
        false ->
            overlaps_rooms(T, Corridor);
        true ->
            true
    end;
overlaps_rooms([_H | T], Corridor) ->
    overlaps_rooms(T, Corridor);
overlaps_rooms([], _Corridor) ->
    false.
