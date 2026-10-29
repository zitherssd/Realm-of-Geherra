# Data formatting

Use four-space indentation, double-quoted strings, spaces around assignments, and
trailing commas on multiline table fields. Keep definition records multiline;
short arrays and small nested option tables may stay compact. Separate catalogue
entries with a blank line. In status and skill catalogues, write explicit string
IDs as `["id"]`; ordinary field names use `field = value`. Both key forms mean the
same thing in Lua when the key is a valid identifier.

The formatter configuration lives here so this convention applies to data without
reformatting unrelated systems. With StyLua installed, run from the repository root:

```powershell
stylua --config-path src/data/stylua.toml --verify src/data
stylua --config-path src/data/stylua.toml --check src/data
```

`--verify` checks formatting output against the input syntax tree. Preserve record
layout when authoring: the formatter retains short inline tables as inline tables.
Do not change values, reorder ordered lists, or rewrite data constructors as part
of formatting.
