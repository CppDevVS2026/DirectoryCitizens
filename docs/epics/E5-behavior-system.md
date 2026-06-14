# E5 — Behavior System

**Goal:** Citizens decide what to do based on their needs, updating status and position autonomously.  
**Owner:** Dev (JcTheKing)  
**Depends on:** E3 (needs running), E2 (The Eye live)  
**Status:** Future

---

## Tasks

### T5.1 — Define Behavior type
```odin
Behavior :: enum {
    Idle,
    Eating,
    Sleeping,
    Socializing,
    Working,
    Wandering,
}
```
Add `behavior: Behavior` to `Citizen` struct.

### T5.2 — tick_behavior() — need-driven decisions
Priority order (highest need wins):
1. hunger >= 70 → seek food → behavior = .Eating, status = "Eating at the {zone} market"
2. sleep <= 30  → rest    → behavior = .Sleeping, status = "Sleeping"
3. social <= 30 → seek company → behavior = .Socializing, status = "Talking with neighbors"
4. otherwise    → work / wander

### T5.3 — Position drift
When behavior changes zone (e.g., hungry citizen walks to Market):
- Gradually lerp `world_pos` toward the target zone center
- Update `zone` field when they arrive
- Write updated `.citizen` file

### T5.4 — Status flavor text (Story Writer task)
For each behavior × zone combo, provide a short status string.
PM will build a lookup table from this.

Example table:
| Behavior | Zone | Status text |
|----------|------|-------------|
| Eating | Market District | "Buying bread at the stalls" |
| Sleeping | Residential Quarter | "Asleep in their home" |
| Socializing | The Keep | "Gossiping with the guards" |

---

## Definition of Done

- Citizens autonomously change their status and position based on needs
- A hungry citizen walks to the Market and their status changes
- The Eye picks up the file change and the HUD updates live
