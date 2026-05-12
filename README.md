# dalejdalej

Monitor GitHub PRs with Claude AI — auto-rebase and CI triage.

Runs as a background daemon every 30 minutes. For each watched PR it:
- rebases onto the base branch if behind or dirty
- inspects CI failures and reruns flaky jobs, or reports real failures

## Requirements

- [Claude Code CLI](https://claude.ai/code) installed and authenticated (`claude`)
- `gh` CLI authenticated (`gh auth login`)

## Install

```sh
brew tap Trurls/dalejdalej
brew install dalejdalej
```

## Usage

### Watch a PR

Run from inside the repo whose PR you want to monitor:

```sh
dalejdalej add          # picks up current branch's PR automatically
dalejdalej add 1234     # or specify a PR number explicitly
```

### Start / stop the daemon

```sh
dalejdalej start        # writes LaunchAgent plist and bootstraps it
dalejdalej stop
dalejdalej status
dalejdalej logs         # filtered  (hides raw tool output)
dalejdalej logs -v      # verbose
```

> **macOS 15+ (Sequoia) note:** on first start macOS will prompt for approval.
> Go to **System Settings → General → Login Items & Extensions** and allow dalejdalej,
> then run `dalejdalej start` again.

### List / remove watched PRs

```sh
dalejdalej list
dalejdalej rm           # interactive picker
dalejdalej rm 1234      # remove specific PR number
```

## Config

`~/.dalejdalej.yaml` — created automatically on first `dalejdalej add`.
Cloned repos land in `~/dalejdalej/<repo-name>/`.

## License

MIT
