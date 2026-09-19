use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

use tauri::menu::{Menu, MenuItem, MenuItemKind, HELP_SUBMENU_ID};
use tauri::Manager;
use url::Url;

mod app_update;
mod embedded_phx_env {
    include!(concat!(env!("OUT_DIR"), "/embedded_phx_env.rs"));
}

static AUX_WINDOW_ID: AtomicU64 = AtomicU64::new(1);

fn print_temp_dir() -> PathBuf {
    std::env::temp_dir().join("safarimanager-print")
}

fn absolutize_print_html(html: &str, origin: &str) -> String {
    html.replace("href=\"/", &format!("href=\"{origin}/"))
        .replace("href='/", &format!("href='{origin}/"))
        .replace("src=\"/", &format!("src=\"{origin}/"))
        .replace("src='/", &format!("src='{origin}/"))
}

fn print_origin(url: &Url) -> String {
    format!("{}://{}", url.scheme(), url.authority())
}

fn write_and_open_print_html(html: String) -> Result<(), String> {
    let dir = print_temp_dir();
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;

    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0);
    let path = dir.join(format!("print-{stamp}.html"));
    std::fs::write(&path, html.as_bytes()).map_err(|e| e.to_string())?;
    open_path(&path)
}

fn open_path(path: &Path) -> Result<(), String> {
    #[cfg(target_os = "macos")]
    {
        std::process::Command::new("open")
            .arg(path)
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
            .arg(path)
            .spawn()
            .map_err(|e| e.to_string())?;
    }

    Ok(())
}

fn open_dir(path: &Path) -> Result<(), String> {
    std::fs::create_dir_all(path).map_err(|e| e.to_string())?;
    open_path(path)
}

/// Capture Elixir stdout/stderr into `log_dir/safarimanager.log` (the old DesktopBridge
/// wrote `~/Library/Logs/Safarimanager.log`; Tauri had no equivalent until now).
fn attach_elixir_logs(cmd: &mut std::process::Command, log_dir: &Path) -> Result<(), String> {
    std::fs::create_dir_all(log_dir).map_err(|e| e.to_string())?;
    let path = log_dir.join("safarimanager.log");
    let file = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
        .map_err(|e| e.to_string())?;
    let err = file.try_clone().map_err(|e| e.to_string())?;
    cmd.stdout(std::process::Stdio::from(file));
    cmd.stderr(std::process::Stdio::from(err));
    Ok(())
}

fn setup_app_menu(app: &tauri::AppHandle) -> tauri::Result<()> {
    let menu = Menu::default(app)?;

    if let Some(MenuItemKind::Submenu(help)) = menu.get(HELP_SUBMENU_ID) {
        help.append(&MenuItem::with_id(
            app,
            "open_logs",
            "Open Logs",
            true,
            None::<&str>,
        )?)?;
        help.append(&MenuItem::with_id(
            app,
            "open_app_data",
            "Open App Data Folder",
            true,
            None::<&str>,
        )?)?;
    }

    app.set_menu(menu)?;
    Ok(())
}

fn is_printout_url(url: &Url) -> bool {
    url.path().contains("_printout")
}

async fn open_print_url(app: &tauri::AppHandle, url: Url) -> Result<(), String> {
    let window = app
        .get_webview_window("main")
        .ok_or_else(|| "main window missing".to_string())?;

    let cookies = window
        .cookies_for_url(url.clone())
        .map_err(|e| e.to_string())?;
    let cookie_header = cookies
        .iter()
        .map(|cookie| format!("{}={}", cookie.name(), cookie.value()))
        .collect::<Vec<_>>()
        .join("; ");

    let client = reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::limited(10))
        .build()
        .map_err(|e| e.to_string())?;

    let mut request = client.get(url.as_str());
    if !cookie_header.is_empty() {
        request = request.header("Cookie", cookie_header);
    }

    let response = request.send().await.map_err(|e| e.to_string())?;
    if !response.status().is_success() {
        return Err(format!("printout fetch failed: {}", response.status()));
    }

    let origin = print_origin(&url);
    let html = absolutize_print_html(&response.text().await.map_err(|e| e.to_string())?, &origin);
    write_and_open_print_html(html)
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

    match tauri::webview::WebviewWindowBuilder::new(app, "main", tauri::WebviewUrl::External(parsed))
        .title("Safari Manager")
        .inner_size(1280.0, 800.0)
        // Printouts (`target="_blank"`) are fetched with the webview session and opened
        // in the system browser. Other `_blank` links get an auxiliary window.
        .on_new_window(move |url, features| {
            if is_printout_url(&url) {
                let app = app_handle.clone();
                tauri::async_runtime::spawn(async move {
                    if let Err(err) = open_print_url(&app, url).await {
                        eprintln!("printout: {err}");
                    }
                });
                return tauri::webview::NewWindowResponse::Deny;
            }

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
        .build()
    {
        Ok(_) => app_update::spawn_check(app.clone()),
        Err(err) => eprintln!("failed to create main window: {err}"),
    }
}

pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_process::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .setup(|app| {
            let handle = app.handle().clone();

            setup_app_menu(&handle)?;

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
            let elixir_log_dir = log_dir.clone();
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

                if let Err(err) = attach_elixir_logs(&mut cmd, &elixir_log_dir) {
                    eprintln!("failed to attach elixir logs: {err}");
                }

                let status = cmd.status().expect("failed to start Elixir release");
                app_handle.exit(if status.success() { 0 } else { 1 });
            });

            Ok(())
        })
        .on_menu_event(|app, event| match event.id().as_ref() {
            "open_logs" => {
                let log_dir = app
                    .path()
                    .app_log_dir()
                    .unwrap_or_else(|_| project_root().join("log"));
                if let Err(err) = open_dir(&log_dir) {
                    eprintln!("open logs: {err}");
                }
            }
            "open_app_data" => {
                if let Ok(data_dir) = app.path().app_local_data_dir() {
                    if let Err(err) = open_dir(&data_dir) {
                        eprintln!("open app data: {err}");
                    }
                }
            }
            _ => {}
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
