# Rust Header TODO

This file tracks the `-xrs` work for CMunge.

## Done

- [x] Add `-xrs <file>` output option.
- [x] Add an initial Rust writer backend.
- [x] Emit core ABI structs and module metadata constants.
- [x] Add a host-side regression for Rust header output.

## Done In This Pass

- [x] Emit command handler support constants and command numbers.
- [x] Emit SWI constants and `error_BAD_SWI`.
- [x] Emit all declared event entry points and handler type aliases.
- [x] Emit vector-trap callback types without unsupported placeholders.
- [x] Emit 64-bit-friendly vector/generic helper constants.
- [x] Emit embedded error symbol declarations for the 64-bit Rust case.
- [x] Add Rust regression coverage for `-zerrors`.
- [x] Use `unsafe extern "C" fn` for generated callback and handler aliases.
- [x] Reject `-xrs` with `-zoslib` and `-zoslibpath`.
- [x] Add regression coverage for unsupported OSLib Rust-header combinations.

## Still Missing

- [ ] Emit Rust equivalents for any remaining callback forms not yet covered by the current tests.
