-module(util).

-export([
    is_shell/0,
    boolean_to_integer/1,
    sign/1,
    generate_delta/1
]).

is_shell() ->
    case init:get_argument(noshell) of
        {ok, _} ->
            false;
        error ->
            true
    end.

boolean_to_integer(true) ->
    1;
boolean_to_integer(false) ->
    0.

sign(X) when X < 0 ->
    -1;
sign(X) when X > 0 ->
    1;
sign(_) ->
    0.

generate_delta(IsVert) ->
    case IsVert of
        true ->
            case rand:uniform(2) of
                1 ->
                    {0, -1};
                2 ->
                    {0, 1}
            end;
        false ->
            case rand:uniform(2) of
                1 ->
                    {-1, 0};
                2 ->
                    {1, 0}
            end
    end.
