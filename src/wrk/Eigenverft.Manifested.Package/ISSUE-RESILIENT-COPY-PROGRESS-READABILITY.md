# Resilient copy progress readability and status formatting

**Status:** Open
**Priority:** 4/7 Medium
**Recommendation:** Use a shared adaptive IEC byte-rate formatter for copy progress, fix the operation-status format expression, and make the queue label explicitly describe pending work.

## Observed behavior

During a large `.gguf` materialization, the nested PowerShell progress display contains output similar to:

```text
Copying Qwen3.5-9B-Q6_K.gguf
924.844.032/7.458.301.152 bytes | 32.167.296 B/s | elapsed 00:00:28.7512909 | ETA 00:03:23.1090000
```

The parent operation status can simultaneously render:

```text
Phase: {0} | files discovered {1:N0}; selected {2:N0}; copied {3:N0}; failed {4:N0}; preflighted 1; removed 0; queued 0 (0 B)
```

The raw byte rate is technically correct but difficult to interpret quickly. The literal format placeholders in the parent status are incorrect and make the remaining counters appear inconsistent.

## Code findings

The relevant implementation is:

```text
src/prj/Eigenverft.Manifested.Package/Support/ExecutionCore/Eigenverft.Manifested.Package.ExecutionCore.ResilientDirectoryTree.ps1
```

1. The per-file progress status around lines 747-749 hard-codes the transfer rate as `{2:N0} B/s`.
2. The detailed copy output around lines 1666-1668 independently hard-codes `{4:N0} B/s`, so both presentation paths can diverge unless they share one formatter.
3. The operation status around lines 1074-1078 concatenates two format strings and then applies `-f`. The observed output strongly indicates that formatting is applied only to the second expression segment, leaving `{0}` through `{4:N0}` literal. The complete concatenated format string must be grouped before applying `-f`, or replaced with one format string.
4. `queued 0 (0 B)` can be correct while one file is actively copying. The queue item is removed and its bytes are subtracted around lines 1809-1811 before processing begins. The displayed queue therefore represents pending items only and excludes the active file. Calling it merely `queued` is easy to misread as total outstanding work.

## Required behavior

### Adaptive throughput unit

Render byte rates using the largest suitable IEC unit while retaining a useful amount of precision:

- below 1 KiB/s: `B/s`;
- below 1 MiB/s: `KiB/s`;
- below 1 GiB/s: `MiB/s`;
- otherwise: `GiB/s`.

For the observed value, the display should be approximately:

```text
30.68 MiB/s
```

Use IEC labels because the module already describes byte-based capacities with `MiB` and `GiB`. Keep the underlying numeric properties, including `AverageBytesPerSecond`, unchanged for programmatic consumers.

A shared private formatter should be used by both live `Write-Progress` output and detailed per-file output. Applying the same formatter to processed/total byte counts and pending queue bytes is recommended for visual consistency, but the throughput display is the minimum requirement.

### Correct parent status formatting

The parent status must never expose composite-format placeholders. A valid rendered example is:

```text
Phase: Copy | files discovered 1; selected 1; copied 0; failed 0; preflighted 1; removed 0; pending 0 (0 B)
```

The format expression should be structured so one `-f` operation receives the complete format string and all arguments.

### Clear queue semantics

Prefer `pending` or `queue pending` over `queued`, because the active item has already been dequeued. Alternatively, expose a separate `active 1` value while retaining `queued` for pending items.

The progress display should make these relationships understandable during a one-file copy:

- `selected 1` means one file was selected for copying;
- `copied 0` means it has not completed yet;
- `pending 0` means no additional file remains in the work queue;
- the current operation/file identifies the active copy.

## Test coverage

Add focused tests beside the existing resilient-directory-tree tests for:

1. adaptive rate boundaries at `0`, below `1 KiB`, exactly `1 KiB`, exactly `1 MiB`, and exactly `1 GiB`;
2. the observed `32,167,296 B/s` value rendering as an approximately `30.68 MiB/s` value;
3. operation status rendering with no literal `{0}` or `{1:N0}` placeholders;
4. all status arguments appearing in the expected positions;
5. pending queue count and bytes becoming zero after dequeue while the active file is still represented by the current operation/file;
6. structured numeric result properties remaining raw byte values and not becoming formatted strings.

## Acceptance

- Large-copy progress presents throughput in an automatically selected `B/s`, `KiB/s`, `MiB/s`, or `GiB/s` unit.
- Live progress and detailed copy output use the same formatting behavior.
- No composite-format placeholders are visible in the parent progress status.
- Queue wording does not imply that the actively copied file is still pending.
- The sample one-file copy has internally understandable status: selected but not yet copied, no pending queue item, and one active current file.
- Automated tests cover unit selection, status formatting, queue semantics, and preservation of raw numeric result fields.
