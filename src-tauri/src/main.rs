//! Desktop shell for Safari Manager (Tauri + ElixirKit + Phoenix).

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    safarimanager_desktop_lib::run();
}
