# User manual: linking competition photo folders

This guide explains how to keep original photos on an external drive or folder on this computer, instead of copying every file into Safari Manager.

You do **not** need this for every competition. Browser upload still works as before and copies files into the app.

---

## What this feature does

1. You **link** one folder on this computer as the competition’s photo root (for example a USB stick or an archive folder).
2. Each participant can have a **subfolder** under that root (for example `01 Rossi Mario`).
3. When you import photos that already sit in a participant’s folder, Safari Manager **leaves the originals where they are** and only builds small **thumbnails** inside the app.
4. If you later unplug the drive, lists and jury can still use thumbnails; a banner warns that the full originals are missing until the folder is available again.

**Important:** Linking always uses folders on the **computer running Safari Manager**. A browser on another machine cannot link a folder on that remote computer.

---



## Before you start

- Create (or open) the competition and enroll participants as usual.
- Organize photos on disk in a clear tree, for example:
  ```text
  SanVito 2021/             ← competition root (you will link this)
    01 Rossi Mario/         ← one folder per participant
      DSC04309.JPG
      DSC04310.JPG
    02 Bianchi Carlo/
      …
  ```
- Prefer **one folder per participant**, with image files directly inside that folder (not nested in extra subfolders).

---



## Step 1 — Link the competition directory

1. Open the competition and go to **Slides**.
2. At the top, find the card **Competition directory**.
3. Click **Link directory…**.
4. Browse to the root folder that contains all participant folders.
5. Click **Use this folder**.

The app writes a small marker file in that folder (`.safarimanager.json`) so it can find the same library again if the drive remounts under a new path.

You should see the root path and a status badge (for example **Reachable**).

### Change or unlink later


| Action             | When to use it                                                                                                                                                                    |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Change folder…** | The root moved, or you want to point at a different copy that keeps the **same participant subfolder names**.                                                                     |
| **Rescan folders** | You added or renamed participant folders on disk and want the app to rediscover mappings from marker files.                                                                       |
| **Unlink**         | You no longer want this competition tied to that root. **Blocked** while any linked slides still exist — delete those slide records first. Unlink never deletes your photo files. |


---



## Step 2 — Assign participant folders

Each enrolled participant can be mapped to a folder **relative to the root** (for example `01 Torre Giancarlo`).

### Option A — Automatic (recommended for first import)

1. Select the participant on the Slides page.
2. If the competition directory is already linked, the file browser opens at that **competition root** so you can open the right participant folder quickly.
3. Import from **inside** that participant’s folder (see [Ways to add slides](#ways-to-add-slides) below).
4. If they had no folder yet, Safari Manager assigns that folder for you.
5. After import finishes, the file browser moves **one level up** (usually back to the competition root) so you can pick the next participant folder.

It will **not** silently switch a participant to a different folder if they already have linked slides from another folder.

### Option B — Manual

1. In **Competition directory** → **Participant folders**, find the participant.
2. Type the relative folder name (as it appears under the root).
3. Click **Save**.

The folder must exist under the linked root. The app also writes a small `.safarimanager-participant.json` marker in that folder.

---



## Ways to add slides

There are three ways to insert photos. They can be mixed in the same competition.

### 1. Browser drag-and-drop / file picker (always a copy)

- Select a participant, then drop files or use the upload control on the Slides page.
- Files are **copied** into Safari Manager’s uploads folder.
- Stored as **internal** slides.
- Use this when photos are not on a linked drive, or when you use Safari Manager from another computer’s browser.



### 2. Browse & import on this computer (can stay linked)

- Select a participant.
- Use the in-app file browser / **direct import** flow to pick files from a folder on the host.
- **Linked (no copy)** when all of these are true:
  - the competition has a linked root,
  - the participant has an assigned originals folder,
  - the files sit **directly** in that participant folder.
- Otherwise the import **copies** into uploads (**internal**), same as browser upload.

Typical workflow for a USB archive:

1. Link the competition root.
2. Select participant “01 Torre Giancarlo”.
3. Browse into `…/01 Torre Giancarlo`.
4. Import the JPGs → originals stay on the stick; thumbnails are created in the app.



### 3. USB / auto-upload dialog (can stay linked)

- When a volume is detected (desktop / discovery mode), the upload dialog can import from folders on that drive.
- Same rules as direct import: files in the assigned participant folder stay **linked**; anything else is **copied**.

---



## Quick comparison


| How you add photos                               | Originals stay on your folder? | Needs linked competition directory?           |
| ------------------------------------------------ | ------------------------------ | --------------------------------------------- |
| Browser upload                                   | No — copied into the app       | No                                            |
| Direct import from participant folder            | Yes — linked                   | Yes (+ participant folder)                    |
| Direct import from elsewhere                     | No — copied                    | Optional (link does not force linked storage) |
| USB / auto-upload dialog from participant folder | Yes — linked                   | Yes (+ participant folder)                    |
| USB / auto-upload dialog from elsewhere          | No — copied                    | Optional                                      |


**Thumbnails** are always kept inside the app for all modes, so the UI can still show small previews when the drive is gone.

---



## If originals become unreachable

When the linked root is missing (USB unplugged, wrong path, etc.), a yellow banner appears on competition pages:

- **Retry** — check again (also tries to find the same library if the drive remounted elsewhere).
- **Locate folder** — opens Slides so you can **Change folder…** or reconnect the drive.

Until the root is reachable again:

- Slide lists, validation, and jury can still use **thumbnails**.
- Full-resolution originals may fall back to a larger preview (same aspect ratio as the photo) when the file is missing.

Plug the drive back in (or change the folder to the new location), then click **Retry**.

---



## Deleting slides and competitions


| What you delete                      | What happens to files on the linked drive                                                            |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------- |
| A **linked** slide in Safari Manager | Only the app record and its thumbnails are removed. The original JPG on disk is **kept**.            |
| An **internal** slide                | The copied original and thumbnails under uploads are removed.                                        |
| The whole **competition**            | App uploads for that competition are cleaned up; linked originals on your drive are **not** deleted. |


---



## Tips

- Keep participant photos **directly** in their folder if you want linked imports (not in `folder/day1/…`).
- Name folders in a stable way; **Change folder…** expects the same relative subfolder names under the new root.
- Large imports can take a while: the app builds a small thumbnail per photo and larger previews in the background for linked slides.
- You can always fall back to browser upload for a few missing files without unlinking the competition.
- Linked slides show a small chain badge next to the file name on the Slides page; copied slides have no badge.

---



## Related technical docs

- Product scope: [LINKED_ORIGINALS.md](./LINKED_ORIGINALS.md)
- On-disk markers and storage rules: [IMAGE_STORAGE.md](./IMAGE_STORAGE.md)

