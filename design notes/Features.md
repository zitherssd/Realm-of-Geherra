# Skills

Skills go from 0 to a maximum of 5.

- Tracking (footprints, hunting trails)
- Shadowcraft (subterfuge, stalking, silently killing)
- Divination (perform rituals, sacrifices, talk to gods)
- Engineering (building stuff)
- Oratory (trade negotations, trickery, public speaking, speech)
- Command/Leadership
- Navigation/Pathfinding
- Foraging?

## Resource bars

- HP bar indicates hp of player unit with a marker and average party hp
- Favor resource bar

## Attributes

- 
 
- On overworld you have HP bar which indicates your hp and average party hp.
You have Favor resource. You earn this resources when winning battles, finishing quests etc. It also acts as a morale modifier for the party in battles. You spend this resource to recruit units, learn skills, etc.
- If alone in party Favor tends towards 100 (maximum). When leading maximum amount of men that you lead it will tend towards 50. Food diveristy or lack of food can change the level towards which Favor tends the bar as well. Recent victories increase tendency temporarilly and they can stack. (3 consecutive wins will give you lots of favor). If Favor is low and decreasing, bad events happen, units desert etc.
- Renown. Gain when completing quest, finishing though battles. Higher renown leads to more difficult quests being given.


Battle.
Conceptually the battle functions like a 2d sidescrollers where 1 parties units spawn on the left side of the stage and another on the right side of the stage. (save for later) the units that are closer to the bottom of the stage will be drawn a bit bigger and those at the top of the stage will be drawing a bit smaller (to give the illusion of depth) (/save for later)



Unit picks target.
Unit moves towards target until it is in range (range is determined by weapon if any) (while moving a 2 frame animation is played)
Units attacks after a windup period. Attack is 3 frames, with attack happening on first frame.
(if target is it range, multiple things can happen, he may block the attack or take the hit)
Repeat for all units on the battlefield.
Units being hit have a chance to block incoming attacks. if that happens an 1 frame animation will be played. blocking can happen while the moving towards his target or during the windup period.
If the unit takes damage he is moved backwards a small distance. He may also enter a stagger state where an animation is played and he moves backwards a bigger distance.