# Linked competition originals

Keep slide **originals** on a host-local folder (external drive, archive tree, etc.) instead of copying them into the app uploads directory. The app still generates **thumbnails** internally so lists, validation, and jury can work when originals are temporarily unavailable.

**Operator guide (simple steps):** [USER_MANUAL_LINKED_ORIGINALS.md](./USER_MANUAL_LINKED_ORIGINALS.md).

Paths are always resolved on the **Elixir host**. A browser on another machine cannot link folders on the client; use normal LiveView upload (internal copy) instead.

## V1 (shipped)

- Link (or later **change**) a **competition directory** (root folder) from the Slides page; assign each participant a **subfolder** under that root (manual, or automatically on the first import from inside the root).
- **Direct import** and **USB import dialog**: if the competition is linked and the file sits directly in the assigned participant folder, slides are stored as `:linked` (no copy). Importing from another folder never re-points a participant who already has linked slides. Browser upload always copies (`:internal`). Both can coexist in one competition.
- **Thumbnails**: small (100×100, square-cropped) on import; medium (fit inside 1280×1280, **same aspect ratio** as the original) generated in the background for linked slides and used as the display fallback when originals are unreachable.
- **Serving**: originals at `GET /slides/:id/original` (not under `/uploads`).
- **Reachability**: background monitor + persistent banner (Retry / Locate folder) when originals are unreachable for the current competition.
- **Relocate**: if the root moves (e.g. USB remount), the app tries to find the same library via `.safarimanager.json` `library_id`.
- **Unlink**: blocked while any `:linked` slides remain (delete slide records first). Unlink never deletes user files.
- **Delete slide / competition**: never deletes linked originals on disk; only internal copies and thumbnails.

## Future (not in V1)

- **Materialize** linked slides into uploads, then unlink (portability without the drive).
- Auto-suggest participant folders from number/name.
- Native Tauri folder picker (today: in-app file browser on the server).
- Bulk convert existing internal slides to linked.
- Cross-machine path remapping beyond volume/`library_id` search.

## Technical details

On-disk markers and path rules: [IMAGE_STORAGE.md](./IMAGE_STORAGE.md).
