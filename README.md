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
| Language | Elixir 1.18+ |
| Framework | Phoenix 1.7+ with LiveView 1.0+ |
| Database | SQLite (default), PostgreSQL (supported) |
| Styling | Tailwind CSS + DaisyUI |
| Image Processing | libvips via `image` |
| Observability | Prometheus (PromEx) + Loki (Svadilfari) |

## Getting Started

### Prerequisites

- Elixir 1.18+
- Erlang/OTP 26+
- Node.js (for asset compilation)
- libvips (for image processing)

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

### Standalone Desktop App (macOS)

Self-contained application bundle with embedded OTP and SQLite:

```bash
MIX_ENV=prod MIX_TARGET=app mix release app
```

See `elixirkit/` for native shell integration details.

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
