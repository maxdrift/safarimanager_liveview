# Safari Manager Architecture

## Overview

Safari Manager is a comprehensive platform for managing underwater photography competitions, specifically "Photo Safari" events where participants photograph fish and marine life. The platform handles the complete competition lifecycle: from event creation and participant enrollment, through photo submission and validation, to jury voting and final results calculation.

---

## Product Domain

### Core Concepts

- **Competition**: A timed event where participants submit photographs of marine subjects. Competitions can be individual or team-based, and are organized by associations/clubs.

- **Participant**: A registered user enrolled in a competition with an assigned number. Participants belong to categories (e.g., Reflex, Compact cameras) which may affect scoring or judging.

- **Team**: A group of participants competing together. Teams aggregate their members' slides for collective scoring.

- **Slide**: A photograph submitted to a competition. Slides progress through states: discarded → submitted for jury review or submitted with fixed points.

- **Subject**: The fish species or marine element depicted in a slide. Every submitted slide must reference a subject. Subjects carry a static **coefficient** (a difficulty/rarity multiplier) and a **type** classification (`fish`, `macro`, `fish_macro`, `ambient`). At scoring time a **dynamic coefficient** is also computed per subject, based on how many participants photographed it in that competition — rarer subjects can earn a higher bonus.

- **Evaluation**: A configurable vote option that jurors assign to slides. Evaluations have a numeric value and are either normal scores or penalty-type votes. Each competition chooses its own set of allowed evaluations and their display order via `CompetitionEvaluation`, so different competitions can use entirely different vote scales.

- **Juror**: A user designated to evaluate slides during the jury phase of a competition.

### Competition Workflow

1. **Setup**: Create competition, configure settings (jury size, slide limits, scoring rules)
2. **Enrollment**: Register participants/teams with assigned numbers and categories
3. **Photo Import**: Upload and associate slides with participants
4. **Selection**: Participants choose which slides to submit for jury vs. fixed points
5. **Validation**: Review submitted slides for correct species identification, flag issues
6. **Jury**: Jurors evaluate slides, optionally via mobile devices
7. **Results**: Calculate rankings based on scores, coefficients, and tiebreakers

---

## Technical Stack

### Core Technologies

| Layer | Technology |
|-------|------------|
| **Language** | Elixir 1.18+ |
| **Framework** | Phoenix 1.7+ with LiveView 1.0+ |
| **Database** | SQLite (primary), PostgreSQL (supported) |
| **Web Server** | Bandit |
| **CSS Framework** | Tailwind CSS with DaisyUI |
| **Build** | Mix, esbuild |

### Key Dependencies

- **Image Processing**: `image` (libvips wrapper) for thumbnails and EXIF extraction
- **Authentication**: bcrypt_elixir for password hashing, built-in Phoenix auth
- **Caching**: Nebulex with local adapter
- **Observability**: PromEx (Prometheus metrics), Svadilfari (Loki logging)
- **CSV Processing**: NimbleCSV for import/export
- **HTTP Client**: Finch/Req/Tesla for external integrations
- **QR Codes**: qrcode_ex for jury mobile access

### Deployment Modes

The application supports two deployment modes:

1. **Server Mode**: Traditional Phoenix deployment with external database
2. **Standalone App Mode**: Desktop application bundle (macOS) with embedded OTP, using ElixirKit for native integration

---

## Architecture Patterns

### Phoenix Contexts

The domain is organized into Phoenix contexts, each encapsulating a bounded context:

| Context | Responsibility |
|---------|----------------|
| `Accounts` | User management, authentication, sessions |
| `Competitions` | Competition lifecycle, settings, allowed evaluations |
| `Participants` | Enrollment, participant-competition associations |
| `Teams` | Team composition and member management |
| `Slides` | Photo management, evaluation, flags, status transitions |
| `Subjects` | Species/subject catalog with coefficients |
| `Evaluations` | Vote types and values configuration |
| `Jurors` | Jury composition and voting permissions |
| `Organizations` | Clubs/associations that organize events |
| `Categories` | Participant categories (camera types) |
| `Results` | Score calculation and ranking logic |

### Schema Design Patterns

- **UUID Primary Keys**: All entities use UUID v4 for portability and merge safety
- **UTC Timestamps**: Microsecond-precision UTC timestamps throughout
- **Composite Keys**: Join tables (e.g., participants, slide_evaluations) use composite primary keys
- **Embedded Schemas**: Complex nested data (dynamic coefficients) stored as embedded schemas with JSON serialization
- **Enum Fields**: Status and type fields use Ecto.Enum backed by configuration

### Context Pattern

Each context follows a consistent structure:

```elixir
use SM, :context  # Imports Ecto.Query, Multi, Repo, Logger, PubSub helpers
```

This macro provides:
- Standard CRUD operations
- PubSub subscription/notification helpers
- Database adapter-aware ILIKE/LIKE fragments

### Schema Pattern

```elixir
use SM, :schema  # Sets up Ecto.Schema with UUID keys, timestamps
```

Schemas include:
- Typed `changeset/2` and `import_changeset/2` functions
- Configuration-driven enum values loaded at compile time
- Type specs for the struct type

### PubSub Integration

Contexts notify subscribers of data changes:

```elixir
{:ok, result}
|> notify_subscribers([:entity, :created])
```

LiveViews subscribe to receive real-time updates, enabling multi-user collaboration.

---

## Web Layer Architecture

### Router Organization

Routes are grouped by authentication requirements:

- **Authenticated**: Main application functionality under `/organize` and `/admin`
- **Unauthenticated**: Login, registration, password reset
- **Special**: Jury ballot box for mobile voting

### LiveView Patterns

The application heavily uses Phoenix LiveView for real-time interactivity:

- **Launcher + Main Pattern**: Complex workflows (Validation, Jury) have a launcher view for setup and a main view for the actual work
- **Sidebar Hook**: Shared navigation state via `on_mount SMWeb.SidebarHook`
- **Push Events**: Server-to-client communication for image viewer updates
- **PubSub Handlers**: `handle_info` callbacks for real-time data synchronization

### Component Architecture

Reusable components live in `components/`:

- **Core Components**: Standard Phoenix generators enhanced with DaisyUI styling
- **Domain Components**: Competition headers, validation checkmarks, jury toolbars
- **Layout Components**: Sidebar, dialogs, grids with drag-and-drop support

### Controller Patterns

Traditional controllers handle:

- CSV/Image bulk exports
- PDF printouts for official results and selection sheets
- File downloads

---

## Key Workflows

### Slide Selection

Participants choose which of their uploaded slides to submit:
- Slides can go to **Jury** (evaluated by jurors) or **Fixed Points** (automatic scoring)
- Configurable limits: max submitted slides, max jury slides, proportional ratios
- Subject assignment during selection

### Validation Phase

Pre-jury review to catch issues:
- Species misidentification detection
- Duplicate species flagging across participants
- Slide flags (wrong subject, unrecognizable, distinction, notes)
- Quick actions: apply corrections, move between jury/fixed

### Jury Phase

Synchronized voting experience:
- Main jury view controls slide progression for all jurors
- Mobile ballot box receives current slide via PubSub broadcast
- Evaluation quorum tracking
- Penalty votes with configurable quorum rules
- Resume from last viewed slide (cached position)

### Results Calculation

Each slide earns a score based on its status and the selected coefficient: jury slides sum all vote values and multiply by the coefficient; fixed-point slides apply a flat multiplier to the coefficient; penalised slides receive a flat negative amount regardless of votes. Dynamic coefficients augment the static subject coefficient based on how commonly each species was photographed across participants. Participant totals are the sum of all their slide scores; teams aggregate across members. Rankings sort by total score, then by slide count, then by how many slides a participant holds at each coefficient value (highest coefficients first). Tied participants share a rank.

→ See [Scoring & Evaluation Reference](SCORING.md) for the full specification.

---

## Data Management

### CSV Import/Export

Full data portability through CSV:
- Import all entity types with idempotent upsert logic
- Export with configurable column sets
- Handle malformed CSVs gracefully

### Image Handling

- Slides stored on filesystem organized by competition/user
- Thumbnail generation at multiple sizes (small, medium, large)
- EXIF metadata extraction and storage
- OpenSeadragon integration for high-resolution viewing

### Caching Strategy

Nebulex local cache for:
- Current slide position in validation/jury (resume capability)
- Session state for standalone app
- Performance optimization for frequent lookups

---

## Observability

### Metrics

PromEx integration provides Prometheus metrics for:
- Phoenix request performance
- Ecto query timing
- BEAM VM statistics
- LiveView lifecycle events

### Logging

Svadilfari integration for:
- Structured logging to Loki
- Request correlation
- Error tracking

### Telemetry

Standard Phoenix telemetry events with custom metrics for:
- Database query performance
- Memory usage
- VM statistics

---

## Internationalization

- Gettext-based translation system
- Italian localization complete
- English as default locale
- Locale-aware date/time formatting

---

## UI/UX Design

### Visual Framework

- **Tailwind CSS**: Utility-first styling
- **DaisyUI**: Component library with 20+ theme options
- **Theme Switching**: Runtime theme selection persisted to preferences
- **Dark/Light Mode**: Full support across all themes

### Key UI Patterns

- **Sidebar Navigation**: Collapsible navigation with admin and organize sections
- **Data Tables**: Sortable, selectable rows with inline actions
- **Dialogs**: Modal dialogs for forms and confirmations
- **Flash Messages**: Auto-dismissing notifications
- **Drag and Drop**: Sortable lists for team members, evaluation order

### Print Layouts

Dedicated print stylesheets for:
- Official competition results
- Participant enrollment lists
- Slide selection sheets
- Team composition documents

---

## Security

### Authentication

- Session-based authentication with secure token storage
- Password hashing with bcrypt
- User confirmation flow via email
- Password reset with time-limited tokens

### Authorization

- Route-level authentication guards
- User-scoped data access
- Juror permission validation before vote acceptance

### Web Security

- CSRF protection on all forms
- Secure browser headers
- SQL injection prevention via Ecto parameterization

---

## Standalone Desktop Mode

ElixirKit integration enables macOS app distribution:

- **Native Shell**: Swift-based application wrapper
- **Embedded OTP**: Full Erlang/Elixir runtime bundled
- **Local Database**: SQLite for portability
- **USB Watcher**: Monitor for external drives with photo imports
- **Graceful Shutdown**: Native shutdown callbacks

---

## Future Direction

Based on the project roadmap, planned enhancements include:

### Near-term
- Update species/subject catalog
- Improve team naming with organization-based defaults
- Enhanced CSV export for competition details
- Warning systems for incomplete operations

### Medium-term
- Roles and permissions system
- Multi-instance synchronization
- Collapsible sidebar for smaller screens
- Pagination/infinite scroll improvements

### Long-term
- Statistical visualizations (charts)
- Digital signature system for photo authenticity
- Magic link authentication
- State machine for competition lifecycle

---

## Design Principles

1. **Offline-First Capable**: SQLite support enables fully local operation
2. **Real-Time Collaboration**: PubSub ensures data consistency across users
3. **Configuration-Driven**: Enums and settings loaded from config, not hardcoded
4. **Functional Core**: Business logic in contexts, side effects at boundaries
5. **Progressive Enhancement**: Core functionality works without JavaScript, enhanced with LiveView
6. **Domain Accuracy**: Model reflects real-world competition rules and workflows

---

## Code Conventions

- **Naming**: snake_case for functions/variables, PascalCase for modules
- **Specs**: Type specs on public functions
- **Changesets**: Separate changesets for create, update, import operations
- **Error Handling**: Let it crash philosophy with supervisor recovery
- **Testing**: ExUnit with comprehensive coverage expectations
- **Style**: Enforced via Credo and Styler
