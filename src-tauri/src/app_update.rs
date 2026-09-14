use tauri::AppHandle;
use tauri_plugin_dialog::{DialogExt, MessageDialogButtons};
use tauri_plugin_updater::UpdaterExt;

/// Checks for app updates after the main window opens (release builds only).
pub fn spawn_check(app: AppHandle) {
    if cfg!(debug_assertions) {
        return;
    }

    tauri::async_runtime::spawn(async move {
        if let Err(err) = check_and_install(app).await {
            eprintln!("app update: {err}");
        }
    });
}

async fn check_and_install(app: AppHandle) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let Some(update) = app.updater()?.check().await? else {
        return Ok(());
    };

    let version = update.version.clone();
    let current = update.current_version.clone();
    let message = format!(
        "Safari Manager {version} is available (you have {current}).\n\nInstall now? The app will restart."
    );

    let install = tauri::async_runtime::spawn_blocking({
        let app = app.clone();
        move || {
            app.dialog()
                .message(message)
                .title("Update available")
                .buttons(MessageDialogButtons::OkCancelCustom(
                    "Install".into(),
                    "Later".into(),
                ))
                .blocking_show()
        }
    })
    .await?;

    if !install {
        return Ok(());
    }

    update
        .download_and_install(
            |_chunk_length, _content_length| {},
            || {},
        )
        .await?;

    app.restart();
}
