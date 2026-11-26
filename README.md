# llama-cozy-cli

> **Cozy CLI** — A lightweight, modular automation tool for streamlining interactions with the `llama.cpp` command-line interface on Linux systems.

This project serves as a high-performance alternative to resource-heavy Electron-based graphical environments (such as LM Studio) and persistent background system daemons (such as Ollama). It provides instant, isolated access to local LLMs while ensuring that system RAM and VRAM are fully released immediately after the chat session is terminated.

## 🎯 Core Concept
The primary objective of `llama-cozy-cli` is to eliminate background resource consumption during local LLM execution. Unlike traditional server solutions that continuously hold allocated GPU memory, this tool initiates the native `llama-cli` binary strictly for the duration of an active dialogue. Upon session termination (`Ctrl+C`), the process exits cleanly and instantly yields all resources back to the operating system.

## ✨ Key Features
- 🚀 **Streamlined Execution:** Encapsulates complex, multi-parameter console commands into concise, native `ai` and `ailist` shell functions.
- 🧠 **Predictive Model Matching:** The underlying logic allows model lookups by partial name patterns, eliminating the need to input lengthy, absolute filename specifications.
- 🔥 **Hardware Acceleration:** Out-of-the-box configuration for complete VRAM offloading to Nvidia GPUs via CUDA (`-ngl 99`) and automated activation of `Flash Attention` for accelerated context processing.
- 📁 **Ecosystem Compatibility:** Native support for existing model cache paths from third-party applications (including LM Studio), preventing redundant file duplication on storage drives.
- 🧼 **Idempotent & Modular Installer:** Safe setup script featuring smart duplication protection (rewriting paths instead of appending duplicates) and a clean uninstallation routine.

## 🛠️ System Requirements & Dependencies
To ensure proper functionality, verify that the following dependencies are available in your system:
1. **`llama.cpp`** toolchain (the `llama-cli` binary must be accessible globally within your `$PATH`).
2. A compatible shell environment: **Fish**, **Bash**, or **Zsh**.
3. The `find` utility (POSIX-compliant).

## 📦 Installation & Setup

The project includes an interactive, cross-shell deployment script. To integrate the utilities into your active shell environment, run the following commands in your terminal:

1. Grant execution permissions to the installer:
   ```bash
   chmod +x install.sh
   ```
2. Execute the installation routine:
   ```bash
   ./install.sh
   ```
3. The script will automatically detect your active shell interpreter, copy the modular auto-loaded functions (or environment hooks), and prompt you for the target directory containing your `.gguf` models.

## 🕹️ User Guide

After restarting your terminal emulator or sourcing its configuration file, two primary commands become available globally:

1. **Display all cached local models along with their file sizes:**
   ```bash
   ailist
   ```
2. **Initialize an interactive chat session with a model (via a keyword pattern):**
   ```bash
   ai <model_name_pattern>
   ```
   *Example:* Running `ai bonsai` will automatically resolve the exact path of the matching Bonsai model within your cache directory and deploy a CLI chat context mapped to 4,096 tokens.

3. **Termination:**
   To close the active session and completely purge the model from your system's RAM/VRAM, issue a standard process interrupt via **`Ctrl + C`**.

## 🧼 Uninstallation
If you wish to remove the tool and restore your configuration files to their pristine state, run the installer with the `--uninstall` flag:
```bash
./install.sh --uninstall
```

## ⚖️ License
This software is open-source and distributed under the terms of the MIT License. You are free to use, modify, and distribute it for both personal and commercial applications.
