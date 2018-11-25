-include("board.hrl").

-define(Name, "Rogue").
-define(Treasure, "The Thingamajig").

-define(InfoRow, ?BoardHeight + 1).
-define(CommandRow, ?InfoRow + 1).
-define(MessageRow, ?CommandRow + 1).

-define(EmptyChar, ".").
-define(HorizWallChar, "-").
-define(VertWallChar, "|").
-define(CornerChar, "+").
-define(DoorChar, "#").
-define(HeroChar, "@").