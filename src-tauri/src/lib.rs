use tauri::Manager;

mod embedded_phx_env {
    include!(concat!(env!("OUT_DIR"), "/embedded_phx_env.rs"));
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

    /// Moves `~/.safarimanager` into `target` unless `SAFARIMANAGER_SKIP_MIGRATION=1`.
    pub fn migrate_legacy_data_dir(log_dir: &Path, target: &Path) -> io::Result<()> {
        if std::env::var("SAFARIMANAGER_SKIP_MIGRATION").as_deref() == Ok("1") {
            log_line(log_dir, "skip migration (SAFARIMANAGER_SKIP_MIGRATION=1)");
            return Ok(());
        }

        let Some(home) = dirs::home_dir() else {
            return Ok(());
        };

        let legacy = home.join(".safarimanager");
        if !legacy.exists() {
            return Ok(());
        }

        if !dir_empty_or_missing(target) {
            let bak = home.join(".safarimanager.bak");
            log_line(
                log_dir,
                &format!("target {target:?} non-empty; renaming legacy to {bak:?}"),
            );
            let _ = fs::rename(&legacy, &bak);
            return Ok(());
        }

        if let Some(parent) = target.parent() {
            fs::create_dir_all(parent)?;
        }

        log_line(log_dir, &format!("migrating {legacy:?} -> {target:?}"));
        if fs::rename(&legacy, target).is_ok() {
            log_line(log_dir, "migrate: rename ok");
            return Ok(());
        }

        copy_dir_recursive(&legacy, target)?;
        fs::remove_dir_all(&legacy)?;
        log_line(log_dir, "migrate: copy+remove ok");
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

    let _ =
        tauri::webview::WebviewWindowBuilder::new(app, "main", tauri::WebviewUrl::External(parsed))
            .title("Safari Manager")
            .inner_size(1280.0, 800.0)
            .build();
}

pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
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
