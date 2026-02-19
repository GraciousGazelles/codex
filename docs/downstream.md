# Downstream / Fork Notes

This fork tracks upstream `main` on the local `main` branch and carries additional patches on `carry/main`.

## Branch Policy

- `main`: fast-forward mirror of upstream `main` (no local commits)
- `carry/main`: upstream + downstream patches (merge-based carry-forward; no rebases)

## Divergence Summary

### TUI: Queue slash commands and model selection while busy

Why:
- Allow queueing follow-up actions while a task is running (without retyping / losing intent)

User-visible behavior:
- Some slash commands can be queued while a task is in progress and will run after the task completes.
- `/status` remains immediate (not queued).
- `/model` opens the picker immediately (the picker action is not queued).
- Selecting a model while busy queues the model change to apply when the current task completes.

Key files:
- `codex-rs/tui/src/chatwidget.rs`
- `codex-rs/tui/src/app_event.rs`
- `codex-rs/tui/src/app.rs`
- `codex-rs/tui/src/bottom_pane/chat_composer.rs`
- `codex-rs/tui/src/chatwidget/tests.rs`
- `docs/tui-chat-composer.md`

## Updating From Upstream

1. Update local `main` from upstream:

```sh
git fetch origin
git switch main
git merge --ff-only origin/main
```

2. Carry-forward onto `carry/main`:

```sh
git switch carry/main
git merge main
git push fork carry/main
```

## Auditing Divergence

- List carried commits:

```sh
git log --oneline main..carry/main
```

- Show a file-level diff summary:

```sh
git diff --stat main..carry/main
```

