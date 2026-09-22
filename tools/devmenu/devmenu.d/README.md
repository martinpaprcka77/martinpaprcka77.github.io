# Fragment schema

`devmenu.d/*.json` extends or overrides the built-in targets. Files are read in
filename order; a later file wins over an earlier one, and any fragment wins over
a built-in target with the same `name`.

## Shape

Either an object with a `targets` array:

```json
{
  "targets": [
    { "name": "bash", "arguments": ["-l"] }
  ]
}
```

or a bare array:

```json
[
  { "name": "bash", "arguments": ["-l"] }
]
```

## Fields

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `name` | string | yes | Command resolved on `PATH`; the merge key (case-insensitive) |
| `arguments` | string[] | no | Fixed arguments passed to the command |
| `enabled` | boolean | no | `false` removes the target; defaults to `true` |

A fragment with no `name` is skipped. A fragment that fails to parse is ignored
with a warning; the rest still load.

## Examples

Override a built-in and add one:

```json
{
  "targets": [
    { "name": "pwsh", "arguments": ["-NoLogo", "-NoProfile"] },
    { "name": "pwsh-preview", "arguments": ["-NoLogo"] }
  ]
}
```

Disable a built-in:

```json
{ "targets": [ { "name": "wt", "enabled": false } ] }
```

See [`sample.json.example`](sample.json.example) for a copy-ready starter. Files
without a `.json` extension are ignored, so the sample is not loaded.
