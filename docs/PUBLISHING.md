# Publishing Toolkit to PowerShell Gallery

> Publishing PowerShell modules to PSGallery for community use.

## Overview

The **Toolkit** module (37 functions, 1.1.0+) is published to [PowerShell Gallery](https://www.powershellgallery.com/packages/Toolkit) to enable one-command installation:

```powershell
Install-Module -Name Toolkit -Scope CurrentUser
```

## Release Process

### 1. Tag the Release

Bump the version in `toolkit/Toolkit/Toolkit.psd1`, then create a git tag:

```powershell
# Edit toolkit/Toolkit/Toolkit.psd1
# Set ModuleVersion = '1.2.0'

git add toolkit/Toolkit/Toolkit.psd1
git commit -m "Bump Toolkit to v1.2.0"
git tag v1.2.0
git push origin main --tags
```

### 2. GitHub Actions Publishes Automatically

A push of tags matching `v*` triggers `.github/workflows/publish.yml`, which:
1. Reads version from `Toolkit.psd1`
2. Calls `Publish-Module` with the PSGallery API key
3. Reports success/failure

**Alternatively**, trigger manually via GitHub Actions → Workflows → "Publish to PSGallery" → "Run workflow".

### 3. Verify on PSGallery

After 1–2 minutes, check:
- https://www.powershellgallery.com/packages/Toolkit/[VERSION]

## Setup (One-time)

### Get PSGallery API Key

1. Create account on [PowerShell Gallery](https://www.powershellgallery.com/users/account/LogOn)
   - Register as user `martinpaprcka77`
   - Verify email

2. Generate API key: PowerShell Gallery → Account → API Keys → "Create" → copy key

3. Add to GitHub Actions Secrets:
   - Repo settings → Secrets and variables → Actions → "New repository secret"
   - Name: `PSGALLERY_API_KEY`
   - Value: [paste API key]
   - Save

### Permissions

Ensure the GitHub Actions token has permission to create releases (usually automatic, but check):
- Repo settings → Actions → General → Workflow permissions → "Read and write permissions"

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `PSGALLERY_API_KEY not set` | Add secret to GitHub repo settings (see Setup above) |
| Publish fails with "already exists" | Version already published; increment version in `.psd1` |
| Module missing on PSGallery | Wait 2–5 min for gallery sync; check workflow run logs |
| API key expired | Regenerate key on PSGallery → Account → API Keys |

## Manual Publishing (Local)

If workflows are unavailable:

```powershell
Publish-Module `
  -Path ~/.config/powershell/toolkit/Toolkit `
  -NuGetApiKey (Read-Host -AsSecureString "PSGallery API Key") `
  -Verbose
```

## Version Strategy

Follow [Semantic Versioning](https://semver.org/):
- `1.0.0` — initial release
- `1.1.0` — added `Test-NetworkHealth`, `Watch-SystemMetrics`
- `1.2.0` — breaking change (major)
- `1.1.1` — bug fix (patch)

Bump in `Toolkit.psd1` `ModuleVersion` before tagging.

## Related

- [Toolkit.psd1](../toolkit/Toolkit/Toolkit.psd1) — module manifest
- [.github/workflows/publish.yml](../.github/workflows/publish.yml) — CI/CD workflow
