# Directory Citizens — Roadmap

```
MILESTONE 1 — The Eye Goes Live
├── E1: Core Data Loop       [IN PROGRESS]
│   ├── T1.1 Create world/ + .citizen files
│   ├── T1.2 scan_world()
│   ├── T1.3 Wire into make_game_state()
│   ├── T1.4 save_citizen()
│   ├── T1.5 Zone color palette
│   └── T1.6 Citizen color from name hash
│
├── E4: World Content        [PARALLEL — Story Writer]
│   ├── T4.1 World lore doc
│   ├── T4.2 Zone definitions
│   ├── T4.3 Starting citizens
│   ├── T4.4 Opening event log
│   └── T4.5 world.cfg values
│
├── E2: The Eye (Win32)      [BLOCKED on E1]
│   ├── T2.1 start_the_eye()
│   ├── T2.2 stop_the_eye()
│   ├── T2.3 drain_eye_events() reactions
│   ├── T2.4 Wire into GameState + main loop
│   └── T2.5 HUD live indicator
│
└── E3: Needs Simulation     [BLOCKED on E1]
    ├── T3.1 Tune tick_needs()
    ├── T3.2 Auto-save on tick
    ├── T3.3 Critical state events
    └── T3.4 Needs → health → death

MILESTONE 2 — Citizens Think
├── E5: Behavior System
│   ├── T5.1 Behavior enum
│   ├── T5.2 tick_behavior()
│   ├── T5.3 Position drift
│   └── T5.4 Status flavor text (Story Writer)
│
└── E6: Politics System (TBD)

MILESTONE 3 — Full Experience (TBD)
├── E7: Music / Audio Reactions
├── E8: Advanced Narrative Events
└── E9: Polish + Release
```
