# Safari Manager

A comprehensive platform for managing underwater photography competitions ("Photo Safari"), built with Elixir and Phoenix LiveView.

## Overview

Safari Manager handles the complete competition lifecycle for underwater fish photography events:

- **Competition Setup** — Configure events with jury settings, scoring rules, and coefficient systems
- **Participant Management** — Enroll competitors, assign numbers, organize into teams
- **Photo Import & Selection** — Upload slides, assign species (subjects), choose jury vs. fixed-point submissions
- **Validation** — Review species identification, flag issues, detect duplicates
- **Jury Voting** — Synchronized voting experience with mobile ballot box support
- **Results & Rankings** — Calculate scores with coefficient multipliers, handle tiebreakers, generate official printouts

## Tech Stack

| Component | Technology |
|-----------|------------|
| Language | Elixir 1.19.x (see [`.tool-versions`](.tool-versions)) |
| Framework | Phoenix 1.7+ with LiveView 1.0+ |
| Database | SQLite (default), PostgreSQL (supported) |
| Styling | Tailwind CSS + DaisyUI |
| Image Processing | `ex_image_resizer` (Rust NIF; precompiled when available) |
| Observability | Prometheus (PromEx) + Loki (Svadilfari) |

## Getting Started

### Prerequisites

- Elixir and Erlang/OTP: pinned in [`.tool-versions`](.tool-versions) (use [asdf](https://asdf-vm.com/) or [mise](https://mise.jdx.dev/) locally); CI uses the same values via [`versions`](versions)
- Node.js (for asset compilation)
- Rust toolchain (`rustc`, `cargo`) for compiling the `ex_image_resizer` NIF from source until precompiled artifacts are published (see `ex_image_resizer` README)

### Installation

```bash
# Clone the repository
git clone https://github.com/maxdrift/safarimanager_liveview.git
cd safarimanager_liveview

# Install dependencies
mix setup

# Start the server
mix phx.server
```

Visit [localhost:4000](http://localhost:4000) in your browser.

### Development

```bash
# Run tests
mix test

# Run linter and formatter
mix precommit

# Interactive shell
iex -S mix phx.server
```

## Deployment

Safari Manager supports two deployment modes:

### Server Mode

Traditional Phoenix deployment with external database:

```bash
MIX_ENV=prod mix release safarimanager
```

### Desktop app (Tauri + ElixirKit)

Native window wrapping the Phoenix server (see [ElixirKit Tauri guide](https://github.com/livebook-dev/elixirkit/blob/main/guides/tauri.md)):

```bash
make app-dev    # local dev (Rust + mix phx.server)
make app-build  # production bundle (requires Rust + MIX_ENV=prod release)
```

Release artifacts are built in CI via `tauri-apps/tauri-action` (see [.github/workflows/release.yml](.github/workflows/release.yml)).

**Updater signing:** set `TAURI_SIGNING_PRIVATE_KEY` (and optional `TAURI_SIGNING_PRIVATE_KEY_PASSWORD`) in GitHub secrets. The public key in [`src-tauri/tauri.conf.json`](src-tauri/tauri.conf.json) must match the generated key. From the repo root:

```bash
make app-updater-keys              # writes src-tauri/updater.pub + src-tauri/updater.key (unencrypted key; -W)
make app-updater-keys-force        # same, but overwrites an existing updater.key (FORCE=1)
```

Then paste the **second line** of `src-tauri/updater.pub` into `plugins.updater.pubkey` in `tauri.conf.json`. Never commit `updater.key` (it is gitignored).

## Documentation

| Document | Description |
|----------|-------------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System architecture, domain model, design patterns |
| [AGENTS.md](AGENTS.md) | Coding conventions for contributors and AI assistants |
| [TODO](TODO) | Project roadmap and pending features |

## Features

### Competition Management
- Individual and team-based competitions
- Configurable jury size, slide limits, and scoring rules
- Static and dynamic coefficient systems
- Multi-category support (camera types)

### Photo Workflow
- Bulk slide import with EXIF extraction
- Thumbnail generation at multiple sizes
- Species/subject assignment with coefficient lookup
- Duplicate detection and validation flags

### Jury Experience
- Desktop jury view with keyboard navigation
- Mobile ballot box via QR code access
- Real-time vote synchronization via PubSub
- Penalty voting with quorum rules

### Results & Reporting
- Sophisticated ranking with tiebreaker logic
- PDF printouts for official results
- CSV import/export for all data
- Participant and selection printouts

### UI/UX
- 20+ DaisyUI themes with runtime switching
- Italian and English localization
- Responsive design with print layouts
- OpenSeadragon for high-resolution image viewing

## License

Private project — all rights reserved.

---

*Built with ❤️ for the underwater photography community*
