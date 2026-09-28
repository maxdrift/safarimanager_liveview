# Image storage contract

Product scope and roadmap: [LINKED_ORIGINALS.md](./LINKED_ORIGINALS.md).

## Modes

| Mode | `slides.storage` | Original on disk | Thumbnails |
|------|------------------|------------------|------------|
| Internal (default) | `:internal` | `{uploads}/{competition_id}/{user_id}/{file_name}` | `{uploads}/…/thumbnails/{size}/{file_name}` |
| Linked | `:linked` | `{root_path}/{originals_folder}/{file_name}` | Same thumbnail path as internal |

All path resolution for originals goes through `SM.Slides.Storage`.

## Competition directory (linked root)

DB: `competition_directories` (`competition_id`, `library_id`, `root_path`).

Participant mapping: `participants.originals_folder` — path **relative to** `root_path`.

### Root marker

File: `{root}/.safarimanager.json`

```json
{
  "version": 1,
  "library_id": "<uuid>",
  "competitions": [
    { "id": "<competition_uuid>", "name": "…", "linked_at": "<iso8601>" }
  ]
}
```

No per-user folder map in this file. Multiple competitions may reference the same root.

### Participant marker

File: `{root}/{folder}/.safarimanager-participant.json`

```json
{
  "version": 1,
  "library_id": "<uuid>",
  "links": [
    {
      "competition_id": "<uuid>",
      "user_id": "<uuid>",
      "number": 1,
      "name": "…"
    }
  ]
}
```

On disk, participant markers are authoritative for folder ↔ participant mapping. The DB caches `originals_folder`. Reconciliation scans subfolders for markers (`SM.CompetitionDirectories.reconcile_participant_folders/1`).

Writes use temp file + rename. Reads ignore unknown JSON fields and malformed entries (markers live on removable media: decode with string keys, 256 KB cap). The root marker must be writable to link; an unreadable one is never overwritten. Participant marker writes are best-effort.

Path rules (`SM.CompetitionDirectories.PathSafety`): participant folders must resolve inside the root, `slides.file_name` must be a plain basename, and `originals_folder` / `storage` are never cast from user params.

## Serving

- Thumbnails: `Plug.Static` at `/uploads/…`
- Originals: `SMWeb.SlideOriginalController` — `Storage.serving_path/1` (original if reachable, else medium, else small)
- Public URL helper: `SM.Utils.slide_path/1` → `/slides/:id/original`
- Thumbnail resize modes: `:small`/`:large` use fill (square crop); `:medium` uses fit (keeps aspect ratio) because it stands in for unreachable originals.

## Deletion

- `:linked`: remove DB row and thumbnails only; **never** `File.rm` the external original.
- `:internal`: remove original + thumbnails under uploads.
- Competition delete: `rm_rf` uploads tree for that competition (thumbnails only if all linked); best-effort manifest cleanup via `SM.CompetitionDirectories.remove_competition_from_manifests/1`, which must run **before** the competition row is deleted (the directory row cascades).

## Reachability

- `SM.CompetitionDirectories.Monitor` polls linked roots (~5s), each check killed after 3s (hung volume → `:unreachable`).
- Status in `SM.Cache`; PubSub `{SM.CompetitionDirectories, [:originals_reachability, competition_id], status}`.
- `check_reachability/1` relocates by `library_id` across mount points before marking `:unreachable`.
- `SMWeb.SidebarHook` only reads the cache (keyed by the `competition_id` route param) and halts these messages; LiveViews never see them.

## Modules

- `SM.CompetitionDirectories` — link/unlink, assign folder, reconcile, reachability
- `SM.CompetitionDirectories.Manifest` — marker I/O
- `SM.Slides.Storage` — path resolution
- `SM.Slides.Importer` — parallel direct/USB import
