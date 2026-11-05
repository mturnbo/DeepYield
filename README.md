# Deep Yield

An isometric space mining game. You command a mining platform near a nebula: mine gases from the nebula, metals from asteroids and ice from passing comets; build out the platform module by module; sell to freighters to pay off The Big Space Corporation's startup loan; and keep enough defenses in place to fend off pirates.

A run ends when the platform runs out of the materials for oxygen, water or energy, or when you choose to sell the station. Your score is the hours the platform kept operating.

The look is inspired by Rymdkapsel: clean, flat-shaded shapes built from simple geometry, on a 360° rotatable isometric view, set against stars and a nebula.

## Status

Early design. The Godot project here is an empty starting point; there's no gameplay yet.

## Design

The design lives in [`docs/`](docs/README.md):

- [Gameplay](docs/design/gameplay.md): how a run starts, what the commander does, and what success looks like
- [Modules](docs/design/modules.md): every platform module, what it takes in and puts out, and how it looks
- [Materials](docs/design/materials.md): the gases, metals and ice, plus units, storage and prices
- [Economy](docs/design/economy.md): the startup loan, repayment and how a run ends
- [Space view prototype](docs/prototypes/space-view.html): a throwaway 3D sketch of the camera and look

## Running the project

1. Install [Godot](https://godotengine.org/download) 4.5 or later.
2. Open Godot, choose **Import**, and select `project.godot` in this folder.

Target platforms: Linux, macOS and Windows.
