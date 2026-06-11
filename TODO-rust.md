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

## Still Missing

- [ ] Emit Rust equivalents for any remaining callback forms not yet covered by the current tests.
- [ ] Cover `-zoslib`/`-zoslibpath` with Rust-side type choices, or reject them explicitly for `-xrs`.
- [ ] Add more regression coverage for unsupported combinations such as `-xrs` with `-zoslib`.
