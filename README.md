# TwinX — Adaptive Path Planning & Collision Avoidance

**SIH 2026 | Problem Statement ID: SIH26037**

TwinX is a simulation-based approach for adaptive path planning and collision avoidance on unstructured Indian roads. The goal is to build and evaluate a closed-loop autonomous-driving engineering system that can perceive dynamic road users, predict their possible movements, assess collision risk, and re-plan the ego vehicle's trajectory.

> **Project status:** In development. Features and results will be updated as they are implemented and validated.

## Objectives

- Handle roads with missing lane markings, irregular boundaries, and mixed traffic.
- Model road users such as cars, buses, trucks, two-wheelers, auto-rickshaws, bicycles, pedestrians, and animals.
- Predict short-term motion and represent uncertainty in surrounding-agent trajectories.
- Plan safe, drivable trajectories using available free space when lane-based planning is unreliable.
- Respond to changing risk through speed control, yielding, braking, or trajectory changes.
- Validate behaviour across repeatable Indian-road scenarios using closed-loop simulation.

## Planned Technical Workflow

1. **Scenario and road environment** — create representative Indian village-road and urban-junction scenarios.
2. **Perception and sensor simulation** — model camera, LiDAR, and radar observations and fuse information into tracked objects.
3. **Motion prediction** — estimate possible future trajectories and uncertainty for nearby road users.
4. **Risk assessment** — evaluate distance, relative velocity, predicted trajectories, time-to-collision, and free space.
5. **Adaptive planning** — use lane-aware planning when markings are reliable; otherwise estimate drivable space and generate local collision-aware trajectories.
6. **Vehicle control** — convert the selected trajectory into steering, acceleration, and braking commands.
7. **Closed-loop validation** — update the environment from vehicle motion, re-observe, and re-plan when conditions change.

## Planned Scenarios

- Indian village road with mixed traffic and unexpected obstacles.
- Indian urban junction with irregular movement and merging traffic.
- Dynamic events such as a pedestrian or pushcart appearing, a two-wheeler cutting in, or cattle crossing.

## Intended Technology Stack

- **MATLAB and Simulink** — algorithm development, control, and closed-loop simulation.
- **RoadRunner** — road and scenario authoring.
- **Automated Driving Toolbox** — driving scenarios, perception/prediction/planning workflows, and evaluation where applicable.
- **Stateflow** — supervisory behaviour and decision logic.
- **Git and GitHub** — source control, documentation, and collaboration.

The exact toolbox requirements and implementation choices will be confirmed as the prototype develops.

## Repository Structure

```text
SIH26037_Adaptive_Path_Planning_Collision_Avoidance/
├── README.md
├── docs/              # Problem statement, architecture, design notes
├── matlab/            # MATLAB scripts and functions
├── simulink/          # Simulink models
├── roadrunner/        # RoadRunner scenes and scenario assets
├── scenarios/         # Scenario definitions and test cases
├── results/           # Plots, metrics, and simulation outputs
├── media/             # Screenshots and demo recordings
└── tests/             # Validation and regression tests
```

Folders can be added as implementation progresses. Avoid committing generated files or large assets unless they are needed; use Git LFS or external storage for large binary files where appropriate.

## Evaluation Metrics

Record measurable results where possible, including collision/near-miss events, minimum separation, time-to-collision, route completion, comfort-related acceleration/jerk, planner response time, and behaviour across different scenarios. Do not report performance claims until they have been measured.

## Getting Started

1. Clone this repository.
2. Open the project in the supported MATLAB release and install the required licensed toolboxes.
3. Add scenarios, models, scripts, and test cases in the relevant folders.
4. Document how to run each experiment and include reproducible settings with results.

Detailed installation and run instructions will be added once the initial working prototype is established.

## Team and Contributions

Add the registered SIH team name, team members, and contribution guidelines here.

## Disclaimer

TwinX is a simulation and prototyping project for research and hackathon evaluation. Simulation results alone do not establish roadworthiness or safety for real-world autonomous vehicle deployment.

## License

A license has not yet been selected. Until one is added, reuse and redistribution should be treated as not granted by default.
