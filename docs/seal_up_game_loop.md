# Seal Up The Game Loop

Mandatory things that have to happen before we're done.

## HUD_TitleScreen

- Name of game (Rogue at the Ren Faire)
- Start Game button
- How to Play button
- Options button
- Credits button

## HUD_HowToPlay
- Also accessible from the game by pressing btnHowToPlay
- Explains the rules and controls, is mostly text.

## HUD_Credits
- Put a text file into a rich text label.
- Back/Close Button

## Fun score increments
- Gain FUN every time a guard starts chasing you.
- Gain a little bit of FUN with every pickpocket. 
- Gain FUN every time you succeed at a coin challenge.
- Score calculated by `FUN + money * finalScoreMoneyMultiplier` which can be set in the gameManager.

## Player victory
- When player is about to step on any exit tile in one of the four gates, a dialog pops up that asks if they're ready to leave, and shows their final score.
- If they accept, the game ends in victory.

## HUD_GameOver
- Show final score 
- Show reason for loss, or victory
- Button for back to main menu.
