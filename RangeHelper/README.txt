==========================================================
 RangeHelper - a range helper for Hunters
==========================================================

WHAT IS THIS?
-------------
Hunters have three "zones" that matter: melee range, a dead zone
where you can neither melee nor shoot, and your shooting range.
It is easy to lose track of which one you're in during a fight.

RangeHelper puts a short piece of text above your target so you
always know. It shows one of four things:

  Melee            You're close enough to hit it in melee.
  DEAD ZONE        Too far to melee, too close to shoot. (Red.)
  Ranged: 25       You can shoot it, and it's about 25 yards away.
  Out of Range     Too far away for your shots. (Gray.)

The "Ranged" number changes color to warn you before you step
into trouble:

  Green    Comfortable. You're in the sweet spot.
  Yellow   Heads up. You're getting close to an edge:
             - close to the dead zone (it's about to turn red), or
             - getting near the maximum range.
  Red      Right at the far edge. One more step back and you're
           Out of Range.

Going closer, you'll see green -> yellow -> DEAD ZONE (red).
Going farther, you'll see green -> yellow -> red -> Out of Range.

INSTALLING
----------
1. Close the game (or be ready to /reload).
2. Copy the whole "RangeHelper" folder into your AddOns folder.
   If you have an older copy, replace it. Keep the "Libs" folder
   inside - it is what makes the distance numbers accurate.
3. Log in on a Hunter. You should see a "RangeHelper: loaded"
   message in chat.

If you log in on a character that is not a Hunter, the addon
will tell you it didn't load for that reason and do nothing else.

GETTING STARTED
---------------
You don't have to change anything. Out of the box it shows the
text for your target (any mob you can attack), whether or not
you're in combat, above both the mob's nameplate and the target
panel.

THE SETTINGS WINDOW
-------------------
To change anything, just type:

       /rh

That opens the RangeHelper settings window. Everything is a click
away - no commands to remember. Changes take effect right away.

   Left side    Which mobs get the text, and where it appears.
   Right side   Text size and height, where the panel text sits,
                the color warning distances, and advanced options.
   Bottom       Test Text   - shows sample text so you can check
                              the display and your size settings.
                Move Text   - lets you drag the text to your own
                              spot (click Lock Text when done).
                Reset Defaults - puts every setting back.

You can also open it from the game's menu:
   Game Menu (Esc) > Options > AddOns > RangeHelper
There you'll find a short explanation and an "Open RangeHelper
Settings" button.

In every mode the text shows in or out of combat.
Press Esc to close the window. Drag its title bar to move it.

Prefer typing? Every setting also has a command. The rest of this
file describes each setting (and its command), and /rh help lists
them in game. /rh status shows your current settings.

THE TWO SETTINGS MOST PEOPLE CARE ABOUT
(In the settings window these are the two groups on the left.)
---------------------------------------

1) WHICH MOBS get the text?       /rh mode ...

   /rh mode target      Only your target (anything you can attack).
                        This is the default and is the least
                        cluttered.
   /rh mode enemy       Only HOSTILE mobs - the red ones. Neutral
                        (yellow) mobs and friendly mobs are skipped.
   /rh mode attackable  Red AND yellow mobs: anything you are
                        able to attack. Friendly mobs are skipped.
   /rh mode all         Every mob with a nameplate, even friendly
                        ones.

   Quick way to remember it, using nameplate colors:
       red mobs     -> shown by enemy, attackable, all
       yellow mobs  -> shown by attackable, all
       green mobs   -> shown by all only

   Example: you're pulling a pack of red mobs and don't want the
   text cluttering the neutral critters walking around. Type:
       /rh mode enemy

   Note: the addon goes by how the mob feels about you (the same
   thing that sets the nameplate color), not by whether it will
   actually attack you. A red mob will attack on sight; a yellow
   one waits until you attack it.

2) WHERE does the text appear?    /rh display ...

   /rh display plate  Above the mob's nameplate. If a mob has no
                      nameplate (for example you turned them
                      off), your target still gets it on the
                      target panel so you never lose it.
   /rh display panel  Above the target (mob) panel only. Your
                      target only, since it's a single panel.
   /rh display both   Both places. (default)

   Example: you like a clean screen and only want the text by the
   panel. Type:  /rh display panel

   IMPORTANT - NAMEPLATES MUST BE ON FOR TEXT OVER MOBS:
   To see the text above a mob's head (the "plate" part of this
   setting), enemy nameplates have to be turned on. Press V in the
   game to toggle enemy nameplates. If they're off, you'll only see
   the text above the target panel, and only for your current
   target. Mobs you aren't targeting have nothing for the text to
   attach to, so they show nothing.

MAKING IT LOOK RIGHT
--------------------
   /rh size 18          Bigger or smaller text (default 14).
   /rh offset 10        Raise the text above the nameplate. Use a
                        negative number to lower it.
   /rh paneloffset 5    Same idea, for the text above the panel.

   Example: the text overlaps the mob's name. Try /rh offset 12.

If the text isn't where you want it at all, /rh unlock shows a
green box you can drag anywhere. Type /rh lock when you're done.
Then /rh anchor custom makes the panel text use that spot
(/rh anchor target puts it back above the target panel).

TUNING THE COLOR WARNINGS (OPTIONAL)
------------------------------------
You can leave these alone. They are for fine-tuning when the
colors change.

   /rh yellow 5   Turn yellow when you're within 5 yards of the
                  far edge (max range).
   /rh red 2      Turn red when you're within 2 yards of the far
                  edge.
   /rh near 3     Turn yellow when you're within 3 yards above
                  the dead zone. Make it bigger to get warned
                  earlier as you close in, smaller for later.

   Example: you want an earlier warning before the dead zone.
   Type:  /rh near 6

Please note: distances come in steps (like 15, then 10), not every
single yard, so colors switch at those steps. If a color changes
at a distance you don't like, nudge these numbers up or down.

ADVANCED (RARELY NEEDED)
------------------------
   /rh min 8      Where the dead zone ends. Normally detected
                  automatically from your shot spells.
   /rh max 35     Where your shots run out. Normally detected
                  automatically.
   /rh reset      Put every setting back to the defaults.

IF SOMETHING LOOKS WRONG
------------------------
   /rh status     Shows all your current settings. A good first
                  check - maybe a mode or display setting isn't
                  what you thought.
   /rh debug      Target a mob first. Prints technical details
                  about what the game reports for range. Copy
                  those lines if you need to ask for help.

Common questions:

  "I see nothing over the mobs, only over the target panel."  Your
      enemy nameplates are probably off. Press V to turn them on.
      (If you turned them on and still see nothing, run /rh status.)

  "I see nothing."  Check /rh status. In the default "target"
      mode the text only shows for your current target, and only
      if it's something you can attack. Make sure you have a mob
      targeted, then try /rh test to check the display itself.

  "It says Out of Range but I can shoot."  Run /rh debug and look
      at the spell lines. If the numbers look wrong, send them
      along.

  "It says it's using spell checks only."  The accurate range
      library didn't load. Make sure the "Libs" folder is still
      inside the RangeHelper folder.

CREDITS
-------
Distance checks use LibRangeCheck-3.0 (MIT license) and LibStub,
bundled in the Libs folder.
