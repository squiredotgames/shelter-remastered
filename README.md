# Shelter Remastered

> A Godot **4.6** top‑down pixel‑art survival game set in an **apocalyptic** world where **zombies** hammer your compound — tear down **destructible walls** unless you hold the line. Reinforce defences, outsmart the horde, and plan **traps** to keep the shelter standing.

## About the game

**Shelter** takes place after civilization cracks: you guard a last refuge while undead try to **breach the walls** strip by strip. Survival means managing damage, repairs, and eventually **trapping** routes so what slips through does not end the run. This remaster keeps that tense loop — fragile perimeter, relentless pressure, improvised defence — while rebuilding tech and content for a cleaner long‑term base.

## About this remaster

**Shelter** was the **first game** from [**SquireDot Games**](https://github.com/squiredotgames) (then **Malfati Studios**), built in **Unity** for a **2019 game jam**. This project is a **ground‑up remaster in Godot**, developed with help from **Cursor** (and the usual art, design, and iteration that follow a jam prototype).

## Repository

**Shelter Remastered** is the active Godot version: tight viewport rendering with integer scaling, depth sorting for props and architecture, and room‑based levels streamed by a small game bootstrapper.

## Features (current)

- Click‑to‑move player with destinations and collision against the environment  
- Wall segments with **health tiers**, damage, and repair flows  
- Level loading through `Game` → instanced levels under `res://levels/`  
- **Y‑sorted** entities (walls, decorations, player) for faux top‑down depth  
- Ongoing work toward **zombie pressure**, **base defence**, and **traps** as the design matures in this engine  

## Requirements

- [Godot **4.6**](https://godotengine.org/download) (project targets **GL Compatibility**)

## Running

1. Clone the repository  
2. Open the project folder in Godot  
3. Run the main scene (**F5**) — entry point is `res://core/game.tscn`  

## License

Apache License 2.0 — see [LICENSE](LICENSE).
