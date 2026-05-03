# Shelter Remastered

> A Godot **4.6** top‑down pixel‑art survival game — click to explore a guarded compound, fight decay on **destructible walls**, and keep the shelter standing.

## Repository

**Shelter Remastered** is an active remake of the Shelter concept: tight viewport rendering with integer scaling, depth sorting for props and architecture, and room‑based levels streamed by a small game bootstrapper.

## Features (current)

- Click‑to‑move player with destinations and collision against the environment  
- Wall segments with **health tiers**, damage, and repair flows  
- Level loading through `Game` → instanced levels under `res://levels/`  
- **Y‑sorted** entities (walls, decorations, player) for faux top‑down depth  

## Requirements

- [Godot **4.6**](https://godotengine.org/download) (project targets **GL Compatibility**)

## Running

1. Clone the repository  
2. Open the project folder in Godot  
3. Run the main scene (**F5**) — entry point is `res://core/game.tscn`  

## License

Apache License 2.0 — see [LICENSE](LICENSE).
