## Notes on this

Just keeping notes of gleam related things

https://github.com/renatillas/mascarpone/pull/4
Had this issue with mascarpone on windows so created this to fix it

Hitting https://github.com/gleam-lang/gleam/issues/5132 quite a bit
^ this went away after removing local reference to mascarpone

## Thoughts on gleam the language:

Very much like elm in a lot of ways in both good and bad ways.

One issue I have is that it's difficult to split things out into their own files. I have a lot of interdependencies but I can't have dependency cycles so I end up just putting a bunch of logic in game.gleam instead of a separate file.
Perhaps I could do something like

- tower.gleam
- enemy.gleam
- tower_enemy.gleam

Where the third file handles logic that interacts with tower and enemy (logic where enemies move towards and attack towers and towers shoot at enemies) but then there could be a proliferation of files that handle both. I do think that having one file per type is very OOP which obviously is not Gleam's model. Would still need the game.gleam file to wire everything up.

Also because it's a game jam I did a lot of dorcing myself to push through and worry about doing things correctly later.

I also think the Elm architecture is cool but not amazing when you have a game loop that handles most things. I think I could've done certain things in a cleaner way though so might be partially on me. Also having to communicate info between tiramisu and lustre is a bit awkward but it is cool how it works.

Minor nitpicks:

- It's weird that list.range() is inclusive on both start and end e.g. list.range(0, 5) generates 6 entries
- list.filter_map should use option instead of result

## Todo

- try out animations
- potentially add way to rotate lucy
- sound effects
- make towers look nicer
- final boss (wave 5?)

done:

- fix up texture loader
- add main menu
- add ui - waves and enemies
- health bars
- delete shots
- add enemies
- add player health
- enemy shot collision
- pause
- help button with controls
- wait on wave end
- add load progress to page
- points
- game over screen
- background
- upgrades to tower
