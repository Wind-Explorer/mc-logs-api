use axum::{Router, extract::ConnectInfo, http::StatusCode, response::IntoResponse, routing::get};
use std::{fs, net::SocketAddr, path::PathBuf};

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
            println!("log read by {addr}");
            let response = format!(
                "{contents}[Log provider] Captured IP address: {}",
                addr.ip()
            );
            (StatusCode::OK, response)
        }
        Err(err) => (
            StatusCode::NOT_FOUND,
            format!("Could not read log file: {err}"),
        ),
    }
}
