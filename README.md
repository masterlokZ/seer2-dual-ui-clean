# Seer2 Dual UI Clean Codebase (Pristine)

This repository contains the pristine, clean extraction and decompilation of the dual UI components from the official Seer2 launcher: **CoreDLL** and **FramePlayer**.

## Repository Structure

`	ext
seer2-dual-ui-clean/
├── CoreDLL/
│   ├── CoreDLL.decrypted.swf    # Baseline decrypted binary (5,675,637 bytes)
│   └── scripts/                 # Full decompiled ActionScript 3 source tree (4,222 files)
│       └── com/taomee/seer2/...
├── FramePlayer/
│   ├── FramePlayer.swf          # Baseline UI binary (1,568,342 bytes)
│   └── scripts/                 # Full decompiled ActionScript 3 source tree (320 files)
│       └── ...
├── .gitignore
└── README.md
`

## Extraction & Decompilation Environment

- **Decompiler**: JPEXS Free Flash Decompiler (FFDec) v26.2.1
- **Runtime**: OpenJDK Temurin JRE 8u502-b07 (64-Bit) with -Xmx4g
- **Source Assets**:
  - CoreDLL.decrypted.swf: Pristine decrypted CoreDLL module unpacked from launcher
  - FramePlayer.swf: Pristine FramePlayer UI component

## Statistics

| Module | Binary File | Binary Size | Decompiled Scripts |
| :--- | :--- | :--- | :--- |
| **CoreDLL** | CoreDLL.decrypted.swf | 5,675,637 bytes (~5.41 MB) | 4,222 AS3 files |
| **FramePlayer** | FramePlayer.swf | 1,568,342 bytes (~1.50 MB) | 320 AS3 files |
| **Total** | - | 7,243,979 bytes (~6.91 MB) | 4,542 AS3 files |

## Purpose

Provides a canonical, version-controlled reference implementation of the pristine Seer2 UI architecture and client scripting layer for analysis, hotpatching, cross-layer verification, and community preservation.
