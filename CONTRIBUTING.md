# Contributing to ImpactBar

Thanks for helping improve ImpactBar.

## Before opening an issue

- Search existing issues for the same behavior or request.
- Confirm that the issue occurs with the latest release or current `main` branch.
- Remove character names and other personal information from screenshots and log excerpts.

## Development

Requirements:

- macOS 13 or later.
- Xcode Command Line Tools with Swift 6 or later.

Run the checks before submitting a pull request:

```sh
swift test --disable-sandbox
scripts/build-app.sh
```

Keep changes focused, add tests for parsing or state-machine behavior, and update `CHANGELOG.md` when a user-visible behavior changes.

## Combat-log fixtures

Use minimal synthetic log lines in tests. Do not commit complete personal game logs or real character names.
