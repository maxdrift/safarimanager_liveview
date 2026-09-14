use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

use tauri::Manager;

mod embedded_phx_env {
    include!(concat!(env!("OUT_DIR"), "/embedded_phx_env.rs"));
}

static AUX_WINDOW_ID: AtomicU64 = AtomicU64::new(1);

/// Writes a printout HTML snapshot and opens it in the system browser.
/// WKWebView cannot paginate tables (thead repeat / row breaks) like Chrome/Safari.
#[tauri::command]
fn open_print_html(html: String) -> Result<(), String> {
    let dir = std::env::temp_dir().join("safarimanager-print");
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;

    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0);
    let path = dir.join(format!("print-{stamp}.html"));
    std::fs::write(&path, html.as_bytes()).map_err(|e| e.to_string())?;

    #[cfg(target_os = "macos")]
    {
        std::process::Command::new("open")
            .arg(&path)
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    #[cfg(target_os = "windows")]
    {
        std::process::Command::new("cmd")
            .args(["/C", "start", "", &path.to_string_lossy()])
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    #[cfg(all(unix, not(target_os = "macos")))]
    {
        std::process::Command::new("xdg-open")
            .arg(&path)
            .spawn()
            .map_err(|e| e.to_string())?;
    }

    Ok(())
}

pub mod migration {
    use std::fs;
    use std::io::{self, Write};
    use std::path::Path;

    pub fn log_line(log_dir: &Path, msg: &str) {
        let _ = fs::create_dir_all(log_dir);
        let path = log_dir.join("migration.log");
        if let Ok(mut f) = fs::OpenOptions::new().create(true).append(true).open(path) {
            let _ = writeln!(f, "{}", msg);
        }
    }

    fn dir_empty_or_missing(path: &Path) -> bool {
        !path.exists()
            || path
                .read_dir()
                .map(|mut d| d.next().is_none())
                .unwrap_or(true)
    }

    fn copy_dir_recursive(src: &Path, dst: &Path) -> io::Result<()> {
        fs::create_dir_all(dst)?;
        for entry in fs::read_dir(src)? {
            let entry = entry?;
            let ty = entry.file_type()?;
            let dest_path = dst.join(entry.file_name());
            if ty.is_dir() {
                copy_dir_recursive(&entry.path(), &dest_path)?;
            } else {
                if let Some(parent) = dest_path.parent() {
                    fs::create_dir_all(parent)?;
                }
                fs::copy(entry.path(), &dest_path)?;
            }
        }
        Ok(())
    }

    fn legacy_symlink_ok(legacy: &Path, target: &Path) -> bool {
        if !legacy.is_symlink() {
            return false;
        }

        let Ok(link) = fs::read_link(legacy) else {
            return false;
        };

        link == target
            || fs::canonicalize(legacy).ok() == fs::canonicalize(target).ok()
    }

    fn symlink_legacy_to_target(log_dir: &Path, legacy: &Path, target: &Path) {
        if !target.exists() {
            log_line(log_dir, &format!("target {target:?} missing; skip symlink"));
            return;
        }

        if legacy_symlink_ok(legacy, target) {
            log_line(log_dir, &format!("legacy {legacy:?} already symlinked to {target:?}"));
            return;
        }

        if legacy.exists() {
            log_line(
                log_dir,
                &format!("legacy {legacy:?} still exists; skip symlink"),
            );
            return;
        }

        let link_target = fs::canonicalize(target).unwrap_or_else(|_| target.to_path_buf());
        log_line(
            log_dir,
            &format!("symlink {legacy:?} -> {link_target:?}"),
        );

        let result = {
            #[cfg(unix)]
            {
                std::os::unix::fs::symlink(&link_target, legacy)
            }
            #[cfg(windows)]
            {
                std::os::windows::fs::symlink_dir(&link_target, legacy)
            }
        };

        match result {
            Ok(()) => log_line(log_dir, "symlink ok"),
            Err(e) => log_line(log_dir, &format!("symlink failed: {e}")),
        }
    }

    /// Moves `~/.safarimanager` into `target` and symlinks it back unless
    /// `SAFARIMANAGER_SKIP_MIGRATION=1`.
    pub fn migrate_legacy_data_dir(log_dir: &Path, target: &Path) -> io::Result<()> {
        if std::env::var("SAFARIMANAGER_SKIP_MIGRATION").as_deref() == Ok("1") {
            log_line(log_dir, "skip migration (SAFARIMANAGER_SKIP_MIGRATION=1)");
            return Ok(());
        }

        let Some(home) = dirs::home_dir() else {
            return Ok(());
        };

        let legacy = home.join(".safarimanager");

        if legacy_symlink_ok(&legacy, target) {
            log_line(log_dir, "legacy already symlinked to target");
            return Ok(());
        }

        if legacy.is_symlink() {
            log_line(
                log_dir,
                &format!("legacy {legacy:?} is an unexpected symlink; leaving as-is"),
            );
            return Ok(());
        }

        if legacy.is_dir() {
            if dir_empty_or_missing(target) {
                if let Some(parent) = target.parent() {
                    fs::create_dir_all(parent)?;
                }

                log_line(log_dir, &format!("migrating {legacy:?} -> {target:?}"));
                if fs::rename(&legacy, target).is_ok() {
                    log_line(log_dir, "migrate: rename ok");
                } else {
                    copy_dir_recursive(&legacy, target)?;
                    let _ = fs::remove_dir_all(&legacy);
                    log_line(log_dir, "migrate: copy+remove ok");
                }
            } else {
                log_line(
                    log_dir,
                    &format!("target {target:?} non-empty; merging {legacy:?} into target"),
                );
                copy_dir_recursive(&legacy, target)?;
                let _ = fs::remove_dir_all(&legacy);
                log_line(log_dir, "merge ok");
            }
        }

        symlink_legacy_to_target(log_dir, &legacy, target);
        Ok(())
    }
}

fn project_root() -> std::path::PathBuf {
    std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("src-tauri directory has a parent (project root)")
        .to_path_buf()
}

fn server_port() -> u16 {
    std::env::var("SAFARIMANAGER_PORT")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(4000)
}

fn create_main_window(app: &tauri::AppHandle, port: u16) {
    if app.get_webview_window("main").is_some() {
        return;
    }

    let url = format!("http://127.0.0.1:{port}/");
    let parsed = url.parse().expect("valid app url");
    let app_handle = app.clone();

    let _ =
        tauri::webview::WebviewWindowBuilder::new(app, "main", tauri::WebviewUrl::External(parsed))
            .title("Safari Manager")
            .inner_size(1280.0, 800.0)
            // Non-print `target="_blank"` / window.open. Printouts are opened in the
            // system browser via `open_print_html` (see assets/js/app.js).
            .on_new_window(move |_url, features| {
                let id = AUX_WINDOW_ID.fetch_add(1, Ordering::Relaxed);
                let label = format!("aux-{id}");
                let blank = "about:blank".parse().expect("about:blank");

                match tauri::webview::WebviewWindowBuilder::new(
                    &app_handle,
                    &label,
                    tauri::WebviewUrl::External(blank),
                )
                .window_features(features)
                .title("Safari Manager")
                .inner_size(1024.0, 768.0)
                .build()
                {
                    Ok(window) => tauri::webview::NewWindowResponse::Create { window },
                    Err(_) => tauri::webview::NewWindowResponse::Deny,
                }
            })
            .build();
}

pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .invoke_handler(tauri::generate_handler![open_print_html])
        .setup(|app| {
            let handle = app.handle().clone();

            let log_dir = handle
                .path()
                .app_log_dir()
                .unwrap_or_else(|_| project_root().join("log"));

            let data_dir = handle
                .path()
                .app_local_data_dir()
                .expect("app_local_data_dir");

            migration::migrate_legacy_data_dir(&log_dir, &data_dir).unwrap_or_else(|e| {
                migration::log_line(&log_dir, &format!("migration error: {e}"));
            });

            let uploads_dir = data_dir.join("uploads");
            let _ = std::fs::create_dir_all(&uploads_dir);

            let port = server_port();
            let pubsub = elixirkit::PubSub::listen("tcp://127.0.0.1:0").expect("pubsub listen");
            let pubsub_url = pubsub.url();

            let win_handle = handle.clone();
            pubsub.subscribe("messages", move |msg| {
                if msg == b"ready" {
                    create_main_window(&win_handle, port);
                }
            });

            let app_handle = handle.clone();
            tauri::async_runtime::spawn_blocking(move || {
                let rel_dir = match app_handle.path().resource_dir() {
                    Ok(p) => p.join("rel"),
                    Err(_) => project_root().join("src-tauri/target/rel"),
                };

                let mut cmd = if cfg!(debug_assertions) {
                    let mut c = elixirkit::mix("phx.server", &[]);
                    c.current_dir(project_root());
                    c
                } else {
                    elixirkit::release(&rel_dir, "safarimanager")
                };

                // Release: values baked in at `cargo tauri build` from the build environment.
                // Debug: no-op; inherit from the parent process (e.g. direnv `.envrc` / `.envrc.custom`).
                embedded_phx_env::apply_release_elixir_env(&mut cmd);

                cmd.env("ELIXIRKIT_PUBSUB", &pubsub_url);
                cmd.env("PHX_SERVER", "true");
                cmd.env("PHX_HOST", "127.0.0.1");
                cmd.env("PORT", port.to_string());
                cmd.env("SAFARIMANAGER_PORT", port.to_string());
                cmd.env("SAFARIMANAGER_HOST", "127.0.0.1");
                cmd.env(
                    "DATABASE_PATH",
                    data_dir.to_str().expect("utf8 DATABASE_PATH"),
                );
                cmd.env(
                    "UPLOADS_PATH",
                    uploads_dir.to_str().expect("utf8 UPLOADS_PATH"),
                );

                let status = cmd.status().expect("failed to start Elixir release");
                app_handle.exit(if status.success() { 0 } else { 1 });
            });

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
