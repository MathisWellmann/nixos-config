# The model id that llama-server's router serves for a `<repo>:<tag>` preset.
# The router renames every preset section (common/preset.cpp `canonical_tag`):
# it keeps only the last `-`/`.` segment of the tag and upper-cases it, so
# `unsloth/foo-GGUF:UD-Q4_K_XL` is served as `unsloth/foo-GGUF:Q4_K_XL`.
# Requests and `/metrics?model=` scrapes with the original tag get a 400.
{lib}: id: let
  m = builtins.match "(.*):([^:]*)" id;
  segments = builtins.filter builtins.isString (builtins.split "[-.]" (builtins.elemAt m 1));
in
  if m == null
  then id
  else "${builtins.head m}:${lib.toUpper (lib.last segments)}"
