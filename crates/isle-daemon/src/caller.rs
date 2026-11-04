// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

//! Who may call what: the methods that read the user's clipboard or steer the assistant (which can type
//! and open things) answer the desktop frontend the island runs in, and no other program on the bus.
//!
//! On GNOME that frontend is GNOME Shell. The KDE port runs as its own process, which claims
//! `io.github.zickrian.isle.Island` on the session bus; the first claim wins, which is the same
//! trust model as the well-known shell name. `ISLE_FRONTEND_BUS_NAME` adds one more name for
//! development builds.

use zbus::message::Header;
use zbus::names::BusName;
use zbus::proxy::CacheProperties;
use zbus::{Connection, fdo};

const SHELL: &str = "org.gnome.Shell";
const ISLAND: &str = "io.github.zickrian.isle.Island";

/// Refuses the call unless it comes from a known island frontend.
pub async fn shell_only(connection: &Connection, header: &Header<'_>) -> fdo::Result<()> {
    let sender = header.sender().map(|s| s.as_str().to_owned());
    for name in frontend_names() {
        let owner = name_owner(connection, &name).await;
        if allowed(sender.as_deref(), owner.as_deref()) {
            return Ok(());
        }
    }
    Err(fdo::Error::AccessDenied(
        "only the island frontend may call this".into(),
    ))
}

/// The well-known names a frontend may hold: GNOME Shell, the KDE island, and
/// optionally one more from `ISLE_FRONTEND_BUS_NAME` for development builds.
fn frontend_names() -> Vec<String> {
    let mut names = vec![SHELL.to_owned(), ISLAND.to_owned()];
    if let Ok(extra) = std::env::var("ISLE_FRONTEND_BUS_NAME") {
        let extra = extra.trim();
        if !extra.is_empty() {
            names.push(extra.to_owned());
        }
    }
    names
}

/// The unique name `name`'s owner has on the bus, if anyone holds it.
async fn name_owner(connection: &Connection, name: &str) -> Option<String> {
    let dbus = fdo::DBusProxy::builder(connection)
        .cache_properties(CacheProperties::No)
        .build()
        .await
        .ok()?;
    let owner = dbus
        .get_name_owner(BusName::try_from(name).ok()?)
        .await
        .ok()?;
    Some(owner.as_str().to_owned())
}

/// True when the sender is the frontend's own bus name; no frontend or no sender never passes.
fn allowed(sender: Option<&str>, frontend: Option<&str>) -> bool {
    matches!((sender, frontend), (Some(sender), Some(frontend)) if sender == frontend)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_the_frontend_gets_in() {
        assert!(allowed(Some(":1.12"), Some(":1.12")));
        assert!(!allowed(Some(":1.40"), Some(":1.12")));
        // No frontend (a test session), or a sender the bus did not name: no.
        assert!(!allowed(Some(":1.40"), None));
        assert!(!allowed(None, Some(":1.12")));
    }

    #[test]
    fn frontend_names_include_shell_and_island() {
        let names = frontend_names();
        assert!(names.contains(&SHELL.to_owned()));
        assert!(names.contains(&ISLAND.to_owned()));
    }
}
