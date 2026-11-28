# 🦙 llama-cozy-cli

**llama.cpp without the monster command lines.** A tiny, daemon-free launcher for local LLMs on Linux.

```console
$ ai qwen 8b          # chat with the model whose filename contains "qwen" and "8b"
$ ai serve qwen       # OpenAI-compatible API + web UI on localhost
$ ai pull unsloth/Qwen3-8B-GGUF:Q4_K_M
$ ailist
```

Ollama and LM Studio keep a service or an Electron app alive and hold on to VRAM. `llama-cozy` just starts the plain `llama-cli` / `llama-server` binary when you ask and **replaces itself with it** (`exec`), so when you hit `Ctrl+C` there is nothing left running and every byte of RAM/VRAM is back immediately.

## ✨ Features

- **Short commands** — `ai <words>` instead of a 200-character `llama-cli -m … -ngl 99 -c 4096 …`.
- **Fuzzy model matching** — case-insensitive, every word must match: `ai qwen 8b q4`. If several models match you get a picker (`fzf` if installed, a numbered menu otherwise) instead of a silent wrong guess.
- **Works in any shell** — it is a normal executable in `~/.local/bin`, not a shell function. fish, bash, zsh, nushell, dash… all behave identically. Tab-completion for fish, bash and zsh.
- **Works on any distro** — pure bash + coreutils. Optional extras: `curl` (for `pull`), `fzf` (nicer picker).
- **GPU-agnostic** — NVIDIA / AMD / Vulkan / CPU: whatever your llama.cpp build supports. `GPU_LAYERS` is configurable, `--cpu` forces CPU.
- **`serve`** — one command for `llama-server` (OpenAI API + web UI), picks a free port automatically.
- **`pull`** — download GGUFs straight from Hugging Face, resumable, handles split models, supports gated repos via `HF_TOKEN`.
- **One-shot & pipes** — `ai qwen -p "Explain TCP"` or `cat notes.txt | ai qwen`.
- **Resumes your last model** — plain `ai` re-opens the previous one.
- **`doctor`** — diagnoses missing binaries, CPU-only builds on GPU machines, wrong paths, leftovers.
- **Reuses existing model folders** (LM Studio, `~/.cache/llama.cpp`, …) — no duplicate multi-GB files. Multimodal `mmproj` files and extra shards of split models are hidden from the list automatically.
- **Safe installer** — idempotent, backs up shell rc files, never touches your models, full `--uninstall`.

## 📦 Install

Requirements: **llama.cpp** (`llama-cli`, ideally `llama-server`), **bash ≥ 4.4** (every current distro), `find`, `du`.

```bash
git clone https://github.com/<your-user>/llama-cozy-cli
cd llama-cozy-cli
./install.sh
```

The installer asks for your models folder (it suggests `~/.lmstudio/models`, `~/.cache/llama.cpp`, … if they exist), installs to `~/.local/bin`, adds it to your `PATH` if needed and sets up tab-completion for the shells you have. Then open a new terminal and run `ai doctor`.

| Option | Meaning |
|---|---|
| `-y, --yes` | non-interactive, use sensible defaults |
| `--models-dir DIR` | models folder |
| `--prompt TEXT` | default system prompt |
| `--prefix DIR` | install elsewhere, e.g. `--prefix /usr/local` (uses `sudo` only if required) |
| `--uninstall [--purge]` | remove everything (`--purge` also deletes settings) |

> **Upgrading from the first version** (fish functions / `~/.llama-cozy-env`)? Just run `./install.sh` again — the old functions, rc blocks and env file are removed (with `.cozy-bak` backups) and your old models path and prompt are carried over. Old fish functions would otherwise shadow the new command.

**llama.cpp not in `PATH`?** Point to your build: `ai config set BIN_DIR ~/llama.cpp/build/bin`.

## 🕹️ Usage

```text
ai [model words…]            chat (no words = last used model, or a picker)
ai run <model> [options]     same, with options
ai list                      show local models          (also: ailist)
ai serve <model>             OpenAI-compatible server + web UI
ai pull <user/repo[:quant]>  download from Hugging Face (default quant: Q4_K_M)
ai rm <model> [-y]           delete a model (all shards)
ai bench <model>             llama-bench
ai doctor                    check the setup
ai config [show|get K|set K V|edit|path]
```

**Run options**

| Option | |
|---|---|
| `-c, --ctx N` | context size (default 4096) |
| `-s, --system TEXT` | system prompt for this session |
| `-p, --prompt TEXT` | answer once and exit (stdin also works) |
| `--cpu` | no GPU offload |
| `-- …` | everything after is passed to llama.cpp untouched, e.g. `ai qwen -- --temp 0.3 --top-p 0.9` |

**Server**

```bash
ai serve qwen                       # http://127.0.0.1:8080  (UI at /, API at /v1)
ai serve qwen --port 9000 --host 0.0.0.0 -- --api-key SECRET
```

Point any OpenAI-compatible client at `http://127.0.0.1:8080/v1`. Binding beyond localhost prints a warning — use `--api-key`.

**Download**

```bash
ai pull unsloth/Qwen3-8B-GGUF               # Q4_K_M
ai pull unsloth/Qwen3-8B-GGUF:Q6_K          # a specific quant
HF_TOKEN=hf_xxx ai pull org/gated-model-GGUF:Q4_K_M
```

Files land in `<MODELS_DIR>/<user>/<repo>/`. Interrupted downloads resume when you run the same command again.

## ⚙️ Configuration

Stored in `~/.config/llama-cozy/config` (plain `KEY=value`, parsed — never `source`d). Manage it with `ai config`.

| Key | Default | |
|---|---|---|
| `MODELS_DIR` | `~/.local/share/llama-cozy/models` | where `.gguf` files live (searched recursively) |
| `SYSTEM_PROMPT` | short helpful-assistant prompt | |
| `CTX` | `4096` | default context size |
| `GPU_LAYERS` | `99` | layers offloaded to GPU (`0` = CPU only) |
| `HOST` / `PORT` | `127.0.0.1` / `8080` | for `ai serve` |
| `BIN_DIR` | *(empty)* | folder with `llama-cli` / `llama-server` if not in `PATH` |
| `EXTRA_ARGS` | *(empty)* | always appended, e.g. `-fa on --temp 0.7` |

Flash attention and colors are left to llama.cpp's own defaults (modern builds enable what your hardware supports). Force it with `ai config set EXTRA_ARGS "-fa on"`.

## 🧩 How it works

`ai` is a symlink to a single bash script. It reads the config, resolves the model, builds the right `llama-cli`/`llama-server` command line and `exec`s it. No daemon, no background process, no shell-specific code — which is why it behaves the same everywhere. Detection for the system-prompt flag (`--system-prompt` vs. the older `-cnv -p`) is automatic.

## 🔧 Troubleshooting

| Symptom | Fix |
|---|---|
| `ai: command not found` | open a new terminal; or add `~/.local/bin` to `PATH`; run `./install.sh` again |
| Old behaviour / wrong `ai` | `ai doctor` reports shadowing functions or another `ai` binary |
| Runs on CPU despite a GPU | `ai doctor` — your llama.cpp build lacks a GPU backend (`-DGGML_CUDA=ON`, `-DGGML_VULKAN=ON`, …) |
| `out of memory` | smaller quant, `-c 2048`, or fewer layers: `ai config set GPU_LAYERS 20` |
| Model not listed | check `ai config get MODELS_DIR`; `mmproj*` files and non-first shards are hidden on purpose |

## 🗺️ Roadmap

- [ ] per-model presets (context, prompt, sampling)
- [ ] `ai chat --image` for multimodal models (`mmproj` auto-pairing)
- [ ] packaging: COPR (Fedora), AUR, `.deb`

PRs and issues welcome.

## ⚖️ License

[MIT](LICENSE)
