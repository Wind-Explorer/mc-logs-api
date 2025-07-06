use axum::{Router, extract::ConnectInfo, http::StatusCode, response::IntoResponse, routing::get};
use std::{fs, io::Write, net::SocketAddr, path::PathBuf};

#[tokio::main]
async fn main() {
    let app = Router::new().route("/logs", get(get_log)).with_state(());

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(
        listener,
        app.into_make_service_with_connect_info::<SocketAddr>(),
    )
    .await
    .unwrap();
}

async fn get_log(ConnectInfo(addr): ConnectInfo<SocketAddr>) -> impl IntoResponse {
    let log_path = PathBuf::from("/data/logs/latest.log");

    match fs::read_to_string(&log_path) {
        Ok(contents) => {
            let timestamp = chrono::Local::now().format("%H:%M:%S");
            let log_entry = format!("[{timestamp}] [Log provider]: Log read by {}\n", addr.ip());
            // Print to stdout
            print!("{log_entry}");
            // Append to ./visits.log
            if let Ok(mut file) = fs::OpenOptions::new()
                .create(true)
                .append(true)
                .open("/data/logs/latest.log")
            {
                let _ = file.write_all(log_entry.as_bytes());
            }
            let response = format!("{contents}{log_entry}",);
            (StatusCode::OK, response)
        }
        Err(err) => (
            StatusCode::NOT_FOUND,
            format!("Could not read log file: {err}"),
        ),
    }
}
