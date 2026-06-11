# Hermes wake-on-demand on a sprite

Why this setup exists, how it works, and how to rebuild it by hand if the
`just` recipes fail. Distilled from the session that built it on sprite
`segundo` (2026-06-06 → 2026-06-11, validated end-to-end).

## Goal

Sprite asleep → from the phone: send a Telegram message, then tap a Firefox
bookmark → sprite wakes → Hermes replies → sprite goes back to sleep.

## Architecture (what is actually running)

Two sprite services + one task hold + one Hermes hook:

| Piece | What it does |
|---|---|
| `waker` service | Owns `--http-port 8080`. Tiny public Python HTTP server (`~/bin/waker.py` via `~/bin/start-waker.sh`). Any GET/HEAD → `PUT /v1/tasks/hermes-active {"expire":"5m"}` on `/.sprite/api.sock` → returns `awake`. The bookmark hits this. |
| `hermes` service | `~/bin/start-hermes.sh` → rebuilds PATH, sources `~/.hermes/.env`, PUTs a startup task, `exec hermes gateway`. Telegram in **long-polling** mode (no `TELEGRAM_WEBHOOK_*` in `.env`). No `--http-port`. |
| Task `hermes-active` | The only thing that holds a sprite awake. Created by the waker on each bookmark hit (5m), recreated by `start-hermes.sh` on boot, and refreshed every agent turn by the hook. When it lapses and nothing else is active, the sprite sleeps. |
| `pre_llm_call` hook | `~/.hermes/agent-hooks/refresh-task.sh`, wired in `~/.hermes/config.yaml` (`hooks.pre_llm_call`, `hooks_auto_accept: true`). Extends the hold while Hermes is actively working. |

Flow: bookmark tap → sprite proxy wakes the VM and routes to the waker →
waker creates the 5m hold → Hermes (resumed with the VM) polls `getUpdates`,
Telegram hands over the queued backlog (it keeps undelivered messages ~24h) →
Hermes replies → hook keeps extending while the conversation is active →
idle past 5m → sleep.

## Key learnings (why it is built this way)

1. **Webhook mode fails on cold wake.** The inbound POST wakes the sprite and
   Hermes generates the reply, but the *outbound* `sendMessage` connection
   died during suspension → `Network error on send: Timed out`. Polling
   self-heals: it retries `getUpdates` until the network is up, *then* sends.
   That asymmetry is the whole reason for polling + external wake.
2. **TCP connections drop on suspend, even on warm wake.** Never assume a
   socket survives a sleep.
3. **Warm wake resumes the frozen process; only cold boot re-runs service
   startup scripts.** Anything that must happen "on wake" cannot live in a
   startup script — hence the waker doing the task PUT per-request.
4. **A service does not keep a sprite awake.** Only the Tasks API does
   (`PUT /v1/tasks/<name>` with `{"expire":"5m"}`, max `1h`, vhost `sprite`
   on `/.sprite/api.sock`). `DELETE` releases.
5. **Only one service can own `--http-port`**, and there is no
   `services update` — changing the owner means `delete` + `create`.
   The proxy routes *all* public URL paths to that service and auto-starts it.
6. **Deleting a service kills its process; recreating starts fresh.** Useful:
   a `services create` is the only reliable way to pick up an edited startup
   script (restart of a *suspended-then-resumed* process won't re-run it).
7. **Service env is bare** — no `.bashrc`, no sprite PATH injection. Startup
   scripts must rebuild PATH from `/etc/profile.d/languages_paths` +
   `languages_env` and source `.env` themselves.
8. **Webhook and polling are mutually exclusive at Telegram's side.** While a
   webhook is registered, `getUpdates` returns 409. Switch with
   `deleteWebhook` (keep pending updates), verify with `getWebhookInfo`
   (`url` must be empty).
9. **An attached console/session keeps the sprite hot** — wake behavior can
   only be tested detached, from the phone.
10. **The waker is public.** It must never serve files (use
    `BaseHTTPRequestHandler`, not `SimpleHTTPRequestHandler`), never source
    `.env`, never echo env or request paths.
11. No systemd/journalctl on sprites. Service logs:
    `/.sprite/logs/services/<name>.log`. Hermes logs: `~/.hermes/logs/gateway.log`.
    Startup-task log: `~/.hermes/logs/task-startup.log`.

## The just recipes

- `just hermes-install` — clone + run upstream installer:
  `git clone --depth 1 https://github.com/NousResearch/hermes-agent.git ~/.hermes/hermes-agent`
  then `./setup-hermes.sh` (interactive: Y to ripgrep; the wizard configures
  LLM keys + Telegram if you want it). Afterwards set in `~/.hermes/.env`:
  `OPENROUTER_API_KEY`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_ALLOWED_USERS`,
  `TELEGRAM_HOME_CHANNEL`. **Never set `TELEGRAM_WEBHOOK_*`.**
- `just hermes-wake-config` — run AFTER keys are set (the gateway dies
  without a bot token). Does the manual steps below.

## Manual procedure (what `hermes-wake-config` automates)

If the recipe fails, do these by hand and verify each against real output:

1. `mkdir -p ~/bin ~/.hermes/agent-hooks ~/.hermes/logs`
2. Copy from this folder: `start-hermes.sh`, `start-waker.sh`, `waker.py`
   → `~/bin/`; `refresh-task.sh` → `~/.hermes/agent-hooks/`.
   `chmod +x` the three `.sh` files.
3. Wire the hook in `~/.hermes/config.yaml` (this is all
   `configure-hooks.py` does):
   ```yaml
   hooks:
     pre_llm_call:
       - command: /home/sprite/.hermes/agent-hooks/refresh-task.sh
         timeout: 10
   hooks_auto_accept: true
   ```
4. `sprite-env services create hermes --cmd $HOME/bin/start-hermes.sh`
   — check `~/.hermes/logs/gateway.log` for
   `Connected to Telegram (polling mode)` and **no 409**. A 409 means a
   webhook is still registered → `curl "https://api.telegram.org/bot$TOKEN/deleteWebhook"`.
5. `sprite-env services create waker --cmd $HOME/bin/start-waker.sh --http-port 8080`
   — `curl -s http://localhost:8080/` must return `awake`, and
   `curl -s --unix-socket /.sprite/api.sock -H "Host: sprite" http://sprite/v1/tasks`
   must show `hermes-active` with a ~5m `expires_at`.
6. From your own machine (not the sprite): set the sprite URL auth to
   **public** (sprite CLI / dashboard). Get the URL from `sprite-env info`
   (`sprite_url`) and bookmark it in the phone's Firefox.
7. Checkpoint: `sprite-env checkpoints create --comment "hermes wake-on-demand ready"`.

## End-to-end test (must be detached)

Close every console/session, wait ~10 min (hold lapses, sprite sleeps).
From the phone: send a Telegram message (no reply expected yet — it only
queues), then tap the bookmark. Reply should arrive within ~1 min.
Afterwards confirm in `gateway.log`: a gap in the 300s `[MEMORY]` ticks
(proves it slept), `getUpdates` draining the backlog, reply sent.

If the VM wakes but no reply ever comes: Hermes' poll loop did not resume —
the known fallback is to make the waker also nudge the `hermes` service
(restart/signal) on wake. This was NOT needed on `segundo`.

## Tuning

- Task expire is `5m` everywhere (waker, startup script, hook). If long
  turns (slow tools) let the hold lapse mid-work, raise to `15m` — it
  appears in `waker.py` (`TASK_EXPIRE`), `start-hermes.sh`, and
  `refresh-task.sh`.
- Anyone with the public URL can wake the sprite (cost: one 5m hold). If
  that bothers you, give the waker a secret path and bookmark that.
