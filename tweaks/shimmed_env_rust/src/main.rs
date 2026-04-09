/// shimmed_env - like /usr/bin/env but with asdf shims prepended to PATH.
///
/// Written in Rust rather than C because we need to explicitly proxy the child's
/// output. Raycast only reads from the fd of the process it directly launched —
/// it does not follow inherited fds through child processes. So we:
///   1. Spawn the target command with piped stdout/stderr
///   2. Forward those pipes to our own stdout/stderr on background threads
///   3. Wait for the child, then exit with its status code
///
/// Build:
///   cargo build --release --manifest-path tweaks/shimmed_env_rust/Cargo.toml
///
/// Install:
///   sudo cp tweaks/shimmed_env_rust/target/release/shimmed_env /usr/local/bin/shimmed_env
///
/// Usage in shebang:
///   #!/usr/local/bin/shimmed_env node
///   #!/usr/local/bin/shimmed_env ruby
///
/// Debug:
///   mkdir -p ~/.config/shimmed_env && touch ~/.config/shimmed_env/debug
///   tail -f /tmp/shimmed_env.log
use std::env;
use std::fs::OpenOptions;
use std::io::{self, Read, Write};
use std::path::Path;
use std::process::{Command, Stdio, exit};
use std::thread;

const VERSION: &str = env!("CARGO_PKG_VERSION");

// Debug logging is enabled by the presence of ~/.config/shimmed_env/debug.
// This sentinel file approach works from Raycast where env vars cannot be set.
//
// Toggle:
//   touch ~/.config/shimmed_env/debug   # enable
//   rm    ~/.config/shimmed_env/debug   # disable
fn is_debug_enabled(home: &str) -> bool {
    Path::new(&format!("{home}/.config/shimmed_env/debug")).exists()
}

fn log(debug: bool, msg: &str) {
    if !debug { return; }
    if let Ok(mut f) = OpenOptions::new().create(true).append(true).open("/tmp/shimmed_env.log") {
        let _ = writeln!(f, "[shimmed_env {VERSION}] {msg}");
    }
}

macro_rules! dbg_log {
    ($debug:expr, $fmt:literal $(, $arg:expr)*) => {
        log($debug, &format!($fmt $(, $arg)*));
    };
}

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        eprintln!("shimmed_env {VERSION}: missing command");
        exit(1);
    }

    if args[1] == "--version" || args[1] == "-V" {
        println!("shimmed_env {VERSION}");
        exit(0);
    }

    let home = env::var("HOME").unwrap_or_else(|_| {
        eprintln!("shimmed_env {VERSION}: HOME not set");
        exit(1);
    });

    let debug = is_debug_enabled(&home);
    log(debug, "--- invoked ---");
    dbg_log!(debug, "invoked with {} args, command='{}'", args.len() - 1, args[1]);
    dbg_log!(debug, "HOME={}", home);

    // Determine ASDF_DATA_DIR (where shims and installs live).
    // Used both to locate shims for PATH and passed to the child.
    let asdf_data_dir = env::var("ASDF_DATA_DIR").unwrap_or_else(|_| {
        let modern = format!("{home}/.local/share/asdf");
        if Path::new(&modern).exists() {
            modern
        } else {
            format!("{home}/.asdf")
        }
    });
    let asdf_shims = format!("{asdf_data_dir}/shims");

    // Determine ASDF_DIR (where asdf's libexec/internals live — needed by shims).
    let asdf_dir = env::var("ASDF_DIR").unwrap_or_else(|_| {
        if Path::new("/opt/homebrew/opt/asdf/libexec").exists() {
            "/opt/homebrew/opt/asdf/libexec".to_string()
        } else if Path::new("/usr/local/opt/asdf/libexec").exists() {
            "/usr/local/opt/asdf/libexec".to_string()
        } else {
            format!("{home}/.asdf")
        }
    });

    // Build new PATH, prepending shims and Homebrew so they're found even in
    // a stripped-down launcher environment.
    let current_path = env::var("PATH").unwrap_or_else(|_| "/usr/bin:/bin".to_string());
    let new_path = format!("{asdf_shims}:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:{current_path}");

    dbg_log!(debug, "ASDF_DIR={}", asdf_dir);
    dbg_log!(debug, "ASDF_DATA_DIR={}", asdf_data_dir);
    dbg_log!(debug, "asdf_shims={}", asdf_shims);
    dbg_log!(debug, "PATH={}", new_path);
    dbg_log!(debug, "full argv: {:?}", args);
    dbg_log!(debug, "spawning: {}", args[1]);

    // Spawn with piped stdout/stderr so we can explicitly forward them.
    // Raycast only reads from the process it directly launched — inherited fds
    // in child processes are not followed.
    let mut child = Command::new(&args[1])
        .args(&args[2..])
        .env("PATH", &new_path)
        .env("ASDF_DIR", &asdf_dir)
        .env("ASDF_DATA_DIR", &asdf_data_dir)
        .stdin(Stdio::inherit())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap_or_else(|e| {
            let msg = format!("failed to spawn '{}': {e}", args[1]);
            log(debug, &msg);
            eprintln!("shimmed_env {VERSION}: {msg}");
            exit(1);
        });

    dbg_log!(debug, "child spawned, pid={:?}", child.id());

    // Forward child stdout → our stdout on a background thread.
    let mut child_stdout = child.stdout.take().unwrap();
    let stdout_thread = thread::spawn(move || {
        let mut buf = [0u8; 4096];
        let mut out = io::stdout();
        let mut total = 0usize;
        loop {
            match child_stdout.read(&mut buf) {
                Ok(0) => break,
                Ok(n) => {
                    let _ = out.write_all(&buf[..n]);
                    let _ = out.flush();
                    total += n;
                }
                Err(e) => { log(debug, &format!("stdout read error: {e}")); break; }
            }
        }
        log(debug, &format!("stdout thread done, forwarded {total} bytes"));
    });

    // Forward child stderr → our stderr on a background thread.
    let mut child_stderr = child.stderr.take().unwrap();
    let stderr_thread = thread::spawn(move || {
        let mut buf = [0u8; 4096];
        let mut err = io::stderr();
        let mut total = 0usize;
        loop {
            match child_stderr.read(&mut buf) {
                Ok(0) => break,
                Ok(n) => {
                    let _ = err.write_all(&buf[..n]);
                    let _ = err.flush();
                    total += n;
                }
                Err(e) => { log(debug, &format!("stderr read error: {e}")); break; }
            }
        }
        log(debug, &format!("stderr thread done, forwarded {total} bytes"));
    });

    let status = child.wait().unwrap_or_else(|e| {
        let msg = format!("wait failed: {e}");
        log(debug, &msg);
        eprintln!("shimmed_env {VERSION}: {msg}");
        exit(1);
    });

    // Drain the forwarding threads before exiting.
    let _ = stdout_thread.join();
    let _ = stderr_thread.join();

    dbg_log!(debug, "child exited with status={}", status);

    exit(status.code().unwrap_or(1));
}

