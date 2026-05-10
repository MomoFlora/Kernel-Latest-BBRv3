<p align="center">
  <img src="https://img.shields.io/badge/BBR-v3-blue?style=for-the-badge&logo=linux&logoColor=white" alt="BBR v3" />
  <img src="https://img.shields.io/badge/Linux-x86__64-yellow?style=for-the-badge&logo=linux&logoColor=white" alt="Linux x86_64" />
  <img src="https://img.shields.io/badge/Debian%2FUbuntu-supported-green?style=for-the-badge" alt="Debian/Ubuntu" />
  <img src="https://img.shields.io/badge/License-MIT-red?style=for-the-badge" alt="MIT License" />
</p>

<h1 align="center">Kernel Latest BBR3</h1>

<p align="center">
  <strong>One-click installer for the latest BBR v3 congestion control kernel</strong><br />
  <em>Optimize your server network performance with a single script</em>
</p>

<p align="center">
  <a href="#features">Features</a> &bull;
  <a href="#quick-start">Quick Start</a> &bull;
  <a href="#usage">Usage</a> &bull;
  <a href="#configuration">Configuration</a> &bull;
  <a href="#troubleshooting">Troubleshooting</a>
</p>

---

## Overview

**Kernel Latest BBR3** is a professional-grade automated installer that deploys the latest BBR v3 (Bottleneck Bandwidth and Round-trip propagation time) congestion control algorithm on Debian/Ubuntu systems.

BBR v3 represents the next generation of TCP congestion control, developed by Google to dramatically improve network throughput and reduce latency on high-bandwidth connections. This script handles the entire installation process, from downloading pre-built kernel packages to applying optimal network configurations.

## Features

<table>
  <tr>
    <td><code>⚡</code> <strong>One-Click Deploy</strong></td>
    <td>Download and install the latest BBR v3 kernel from GitHub Releases automatically</td>
  </tr>
  <tr>
    <td><code>🔧</code> <strong>Multiple QDisc Support</strong></td>
    <td>Choose from FQ, FQ_CODEL, FQ_PIE, or CAKE queue disciplines to match your workload</td>
  </tr>
  <tr>
    <td><code>📊</code> <strong>Real-Time Analysis</strong></td>
    <td>Detect BBR version, current congestion algorithm, and queue discipline instantly</td>
  </tr>
  <tr>
    <td><code>💾</code> <strong>Persistent Configuration</strong></td>
    <td>Save network settings across reboots with automatic sysctl module management</td>
  </tr>
  <tr>
    <td><code>🛡️</code> <strong>Security Hardening</strong></td>
    <td>Automatically disable vulnerable kernel modules (algif_aead, esp4, esp6, rxrpc)</td>
  </tr>
  <tr>
    <td><code>🔄</code> <strong>Clean Uninstall</strong></td>
    <td>Remove custom kernel packages and restore system to default state</td>
  </tr>
</table>

## System Requirements

| Component | Requirement |
|-----------|-------------|
| **Architecture** | `x86_64` (AMD64) |
| **Operating System** | Debian 11+, Ubuntu 20.04+ |
| **Privileges** | `root` or `sudo` access |
| **Network** | Internet connection for GitHub API access |

> [!NOTE]
> Required dependencies (`curl`, `wget`, `dpkg`, `awk`, `sed`, `sysctl`, `jq`) are automatically installed if missing.

## Quick Start

### Option 1: Pipe to Bash

```bash
bash <(curl -l -s https://raw.githubusercontent.com/MomoFlora/kernel-latest-bbr3/dev/install.sh)
```

### Option 2: Manual Installation

```bash
# 1. Download the installer
wget https://raw.githubusercontent.com/MomoFlora/kernel-latest-bbr3/master/install.sh

# 2. Grant execution permission
chmod +x install.sh

# 3. Launch the installer
sudo ./install.sh
```

## Usage

Upon execution, the installer presents an interactive control panel:

```
 ███╗   ███╗ ██████╗ ███╗   ███╗ ██████╗ 
 ████╗ ████║██╔═══██╗████╗ ████║██╔═══██╗
 ██╔████╔██║██║   ██║██╔████╔██║██║   ██║
 ██║╚██╔╝██║██║   ██║██║╚██╔╝██║██║   ██║
 ██║ ╚═╝ ██║╚██████╔╝██║ ╚═╝ ██║╚██████╔╝
 ╚═╝     ╚═╝ ╚═════╝ ╚═╝     ╚═╝ ╚═════╝ 
        Kernel BBR3 Auto-Installer

 Repository: https://github.com/MomoFlora/kernel-latest-bbr3
 Architecture: x86_64 | OS: Debian/Ubuntu
 =========================================================

  Current TCP Algorithm : bbr
  Current Queue         : fq
 ---------------------------------------------------------
  1. Install / Update to latest BBR v3 kernel
  2. Check system BBR runtime status
  3. Enable BBR + FQ (standard recommendation)
  4. Enable BBR + FQ_CODEL
  5. Enable BBR + FQ_PIE
  6. Enable BBR + CAKE
  7. Uninstall custom kernel components
  8. Exit
 ---------------------------------------------------------
```

### Menu Reference

| ID | Function | Description |
|----|----------|-------------|
| `1` | **Install Kernel** | Fetches and installs the latest BBR v3 `.deb` packages from GitHub Releases. Reboot required after installation. |
| `2` | **System Scan** | Analyzes and displays the current BBR version, TCP congestion algorithm, and queue discipline. |
| `3` | **BBR + FQ** | Applies the standard BBR + FQ configuration. Ideal for most server workloads. |
| `4` | **BBR + FQ_CODEL** | Combines BBR with FQ_CODEL for latency-sensitive applications. |
| `5` | **BBR + FQ_PIE** | Uses FQ_PIE queue discipline for adaptive buffer management. |
| `6` | **BBR + CAKE** | Enables CAKE qdisc for advanced traffic shaping capabilities. |
| `7` | **Uninstall** | Purges all custom BBR3 kernel packages and updates GRUB. |
| `8` | **Exit** | Terminates the script. |

## Queue Discipline Comparison

| QDisc | Best For | Characteristics |
|-------|----------|-----------------|
| **FQ** | General purpose | Flow queue with fair bandwidth allocation |
| **FQ_CODEL** | Low-latency apps | Combines fair queuing with Controlled Delay algorithm |
| **FQ_PIE** | Adaptive workloads | Proportional Integral controller for buffer management |
| **CAKE** | Traffic shaping | Comprehensive AQM with automatic bandwidth estimation |

## Configuration Files

The installer manages the following system configuration paths:

| File Path | Purpose |
|-----------|---------|
| `/etc/sysctl.d/99-momoflora-bbr.conf` | Persistent TCP congestion control and qdisc settings |
| `/etc/modprobe.d/99-momoflora-security.conf` | Kernel module security blacklist |
| `/etc/modules-load.d/momoflora-qdisc.conf` | Queue discipline kernel module auto-load |

## Security Profile

The installer applies the following kernel module restrictions on startup:

```
blacklist algif_aead    # Asynchronous AEAD algorithm interface
install algif_aead /bin/false

blacklist esp4          # IPsec ESPv4 protocol
install esp4 /bin/false

blacklist esp6          # IPsec ESPv6 protocol
install esp6 /bin/false

blacklist rxrpc         # RxRPC protocol
install rxrpc /bin/false
```

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `GITHUB_TOKEN` | GitHub API authentication token to bypass rate limiting |
| `GH_TOKEN` | Alternative GitHub CLI token (fallback) |

### Example with API Token

```bash
export GITHUB_TOKEN=ghp_your_token_here
sudo ./install.sh
```

## Kernel Build Configuration

The `configs/` directory contains the complete x86_64 kernel configuration used to compile the BBR v3 kernel packages. This configuration targets Linux 6.12.3 with BBR v3 support and optimized network stack parameters.

## Troubleshooting

### BBR Version Mismatch

**Symptom**: Script reports "BBR version not v3"

**Resolution**:
1. Run option `1` to install the latest kernel
2. Reboot the system
3. Run option `2` to verify the new BBR version

### Configuration Not Persisting

**Symptom**: Settings revert after reboot

**Resolution**: When applying configurations (options 3-6), confirm "yes" when prompted to save settings permanently.

### GitHub API Rate Limit

**Symptom**: Failed to fetch latest version information

**Resolution**: Set a GitHub API token before running:

```bash
export GITHUB_TOKEN=your_token_here
```

## License

This project is distributed under the MIT License. See [LICENSE](LICENSE) for the full license text.

## Author

**[MomoFlora](https://github.com/MomoFlora)** &mdash; Building tools for better network performance.

---

<p align="center">
  <sub>Optimize your network. Deploy BBR v3 today.</sub>
</p>
