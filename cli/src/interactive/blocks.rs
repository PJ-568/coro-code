//! Provide some utility functions for output blocks

use coro_core::tools::output_formatter::{GRAY, RED, RESET, YELLOW};
use iocraft::hooks::StdoutHandle;

use crate::interactive::text_utils::wrap_text;

pub fn normal(stdout: &StdoutHandle, msg: &str) {
    let max_width = crossterm::terminal::size()
        .map(|(w, _)| w as usize)
        .unwrap_or(80);

    stdout.println("");
    for it in wrap_text(msg, max_width) {
        stdout.print(it);
    }
}

pub fn gray(stdout: &StdoutHandle, msg: &str) {
    let max_width = crossterm::terminal::size()
        .map(|(w, _)| w as usize)
        .unwrap_or(80);

    stdout.println("");
    for it in wrap_text(format!("{}{}{}", GRAY, msg, RESET).as_str(), max_width) {
        stdout.print(it);
    }
}

pub fn yellow(stdout: &StdoutHandle, msg: &str) {
    let max_width = crossterm::terminal::size()
        .map(|(w, _)| w as usize)
        .unwrap_or(80);

    stdout.println("");
    for it in wrap_text(format!("{}{}{}", YELLOW, msg, RESET).as_str(), max_width) {
        stdout.print(it);
    }
}

pub fn red(stdout: &StdoutHandle, msg: &str) {
    let max_width = crossterm::terminal::size()
        .map(|(w, _)| w as usize)
        .unwrap_or(80);

    stdout.println("");
    for it in wrap_text(format!("{}{}{}", RED, msg, RESET).as_str(), max_width) {
        stdout.print(it);
    }
}
