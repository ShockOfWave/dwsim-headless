# Project Approach: What We Did and What the Alternatives Were

## What We Did

We essentially solved two problems:

1. **Project format** -- DWSIM uses old-style `.csproj` files targeting .NET Framework 4.6.x (Windows only). We converted 31 projects to SDK-style targeting .NET 8 (cross-platform).

2. **WinForms dependencies** -- the DWSIM core (thermodynamics, solvers, unit operations) is clean, but UI code is interspersed throughout: editing forms, dialogs, `System.Drawing`, `System.Windows.Forms`. We removed or wrapped this code using `#If Not HEADLESS` and `<Compile Remove="...">`.

## Alternative Approaches

### 1. Windows Containers

Run DWSIM as-is in Windows Docker. It works, but:
- Image size ~10+ GB (Windows Server Core)
- Requires a Windows host (or Hyper-V)
- Impractical for the cloud (AWS/GCP are Linux-based)

### 2. Mono on Linux

.NET Framework 4.6.x can be run through Mono. But:
- The WinForms implementation in Mono is incomplete and buggy
- DWSIM uses many Windows-specific APIs
- Unstable, not production-ready

### 3. Wine + .NET Framework

Run Windows .NET under Wine. Works for simple programs, but:
- Heavy, unreliable
- Debugging is a nightmare
- Not suitable for server use

### 4. REST API Wrapper (Without Modifying DWSIM)

Run DWSIM on a Windows machine, expose a REST API, call it from Linux:
- Does not require code modification
- But adds network latency, a separate Windows server, deployment complexity

### 5. Multi-target (Both Windows and Linux) -- The Most Correct Approach

This is what our approach is closest to. The idea:

```xml
<TargetFrameworks>net462;net8.0</TargetFrameworks>
```

And in code:

```vbnet
#If NETFRAMEWORK Then
    ' WinForms code -- works on Windows
    Dim editor As New FormEditor()
    editor.Show()
#Else
    ' .NET 8 -- headless, cross-platform
    ' Skip UI
#End If
```

In essence, this is what we did via the `HEADLESS` symbol, but there is a nuance -- **this could be done within DWSIM itself**, not in a fork. Then:
- One repository, one codebase
- `dotnet build -f net462` -- full Windows version with UI
- `dotnet build -f net8.0` -- headless for Linux/Mac/Windows
- The author could accept this as a PR

## Why We Chose a Fork

We maintain a fork of [DanWBR/dwsim](https://github.com/DanWBR/dwsim) with a dedicated `headless` branch where all modifications are applied directly to the source code.

- **A PR to DWSIM would require significant effort** -- the approach for 37+ projects would need to be agreed upon with the author, testing on Windows, backward compatibility
- **A fork with a dedicated branch is a pragmatic compromise** -- all changes are tracked in git, can be rebased onto new upstream commits, and the full diff is visible
- **Our changes serve as a prototype for a potential upstream PR** -- if the DWSIM author is interested in cross-platform support, the fork demonstrates exactly what needs to be done

## Conclusion

The most "correct" path is **a PR to upstream DWSIM** with multi-targeting. Our fork with the `headless` branch is essentially a prototype of such a PR. The changes are documented in [architecture.md](architecture.md) and effectively show the author what needs to be done for cross-platform support. When upstream DWSIM is updated, we rebase the `headless` branch onto the new commits, resolving any conflicts that arise from new WinForms code or changed method signatures.
