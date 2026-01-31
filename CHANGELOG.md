# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.05] - 2026-01-31

# Release Notes

This release introduces integrated Docker support and a unified core processing pipeline for high-speed cross-platform performance. Key updates include heuristic metadata hashing, concurrent manifest restoration (undo), safe asset purging, and increased robustness to deliver a more stable and efficient environment.

### Added
- Integrated Docker support via `--docker`, plus `--docker-rebuild` and `--docker-remove` for container management.
- High-speed rollback engine for manifest-compliant, 1:1 asset reversion via the `--undo` argument.
- Hardened game asset and cache `--purge` with multi-layer path validation and an interactive selection mode.

### Changed
- Eliminated process-forking overhead by replacing external string tools with native Bash logic.
- Enhanced reset logic to reliably purge hidden directories and all non-core data.
- Enhanced Steam library detection on writable and live media filesystems.
- Ensured module files are sourced safely, with clear error output on failure.
- Hardened file tracking with heuristic 1MB bit-stream sampling for precise, high-speed change detection.
- Hardened parallel execution with atomic file-locking to prevent synchronization race conditions.
- Hardened update deployments with shallow cloning and metadata exclusion for a cleaner environment.
- Implemented conditional bypass logic via force-flag parameters to streamline automated maintenance tasks.
- Implemented guard-clause logic to accelerate re-scans by bypassing overhead on skipped files.
- Improved dependency resolution with absolute path mapping for better reliability across subshells.
- Improved live monitoring and file processing responsiveness by removing artificial delays.
- Improved temporary file handling with isolated folders to avoid /tmp quota exhaustion.
- Improved update resilience with network-aware timeouts and atomic file-integrity verification.
- Isolated temp folders with automatic cleanup for safe, collision-free single-file processing.
- Made path handling compatible with all supported Bash versions.
- Optimized hashing to be unique per path and stable based on file size and modification time.
- Optimized worker logic to defer hashing until extraction success is verified.
- Post-update migration logic refined to ensure a consistent, fresh baseline across all previous versions.
- Preserved skip-processed behavior by writing new hashes exclusively from the main process.
- Reduced disk usage via optimized synchronization and automatic per-BSP cleanup.
- Refined progress UI and ETA updates for smoother, non-blocking operation.
- Standardized re-execution flow with fixed entry-point targeting for stability across symlinks.
- Standardized single and parallel worker flows for consistent state and hash integrity.
- Streamlined configuration tracking by centralizing version metadata within a persistent environment file.
- Streamlined dependency updates with robust release parsing and time-based throttling.
- Unified parallel and monitor workloads into a single, resilient processing engine.

### Fixed
- Eliminated unsafe text handling that could break output.
- Fixed circular name references in nameref lookups to improve compatibility with newer Bash versions.
- Hardened creation/removal validation to prevent invalid or dangerous paths.
- Improved edge-case protections against accidental deletion of critical filesystem paths.
- Prevented directory creation from silently using invalid paths.
- Prevented hangs in non-interactive environments.
- Refined exit and signal handling to ensure reliable cleanup of temp files and orphaned processes.
- Removed fragile numeric comparisons from prompts to prevent unary operator errors.
- Resolved ARG_MAX edge case by routing BSP files via stdin.
- Resolved state-drift by ensuring hash caches are only updated upon verified task completion.
- Silenced secondary CLI output to prevent terminal clutter while maintaining exit-code validation.
- Updated .bsp file collection to ignore invalid filenames and handle case variations safely.

### Contributors
- Thanks to @bl8demast3r, @Takehiko2k, and @Ethorbit for their requests, suggestions, and ideas!

## [v1.04] - 2025-06-24

### Added
- Modular code rewrite, cleanup, and increased usability to better streamline script functionality
- Improved game multiprocessing and pathing organization for map asset extraction and synchronization
- Improved logging functionality; all logs are now found in the `log` folder in the script root path
- Automation support for background map processing via script runtime argument, systemd service, and Steam launch command
- System notification popup functionality for processed maps when using background service/Steam monitors (can be disabled by setting `use_popup=0` in the main script)
- Automatic support for optionally installing missing dependencies on multiple Linux distributions
- Script reset runtime argument to restore stock functionality and optionally stop/remove existing script services

### Contributors
- Big thank you to @Sasha-Acoiners, @victorlisman, and others for their requests, suggestions, and ideas!

## [v1.03] - 2025-05-10

### Added
- Automatic configuration preset generation for quick reprocessing of new/existing map files on a per-game basis
- Automatic updating for the core script and increased update check frequency for user-space tools (VPKEdit)
- Option to scan for external Steam libraries
- Improved Steam detection support for Debian-based distributions

### Changed
- Code optimization, cleanup, and usability improvements to streamline script functionality
- Additional speed optimizations for parallel processing subroutine

### Contributors
- Thank you to @milkcanworld for reporting on external Steam libraries!

## [v1.02] - 2025-04-09

### Added
- Option to optionally skip previously processed map files at startup (greatly improves speed)
  - Uses SHA1 checksums for unique map fingerprinting
  - Per-game basis for flexibility
  - Can be bypassed by answering "N" at prompt or deleting the game's hash folder

### Changed
- Code optimization and cleanup
- Updated output file logging for better readability
- Additional speed optimizations for parallel processing (improved time and I/O usage)

### Contributors
- Thank you to @owlonpc and @jwMaxwell for their suggestions and ideas!

## [v1.01] - 2025-03-08

### Added
- Parallel processing using GNU Parallel with a FIFO streaming buffer
  - ~10x speed improvement (e.g., ~1500 maps from 35+ minutes to 3-4 minutes on modern systems)

### Changed
- Code optimization and cleanup
- VPKEdit update now runs periodically instead of every script run

### Note
- This version requires the `parallel` package as a dependency

### Contributors
- Thank you to @owlonpc for the parallel processing suggestion!

## [v1.00] - 2025-03-07

### Added
- Initial release

[v1.04]: https://github.com/scorpius2k1/linux-bsp-casefolding-workaround/compare/v1.03...v1.04
[v1.03]: https://github.com/scorpius2k1/linux-bsp-casefolding-workaround/compare/v1.02...v1.03
[v1.02]: https://github.com/scorpius2k1/linux-bsp-casefolding-workaround/compare/v1.01...v1.02
[v1.01]: https://github.com/scorpius2k1/linux-bsp-casefolding-workaround/compare/v1.00...v1.01
[v1.00]: https://github.com/scorpius2k1/linux-bsp-casefolding-workaround/releases/tag/v1.00
