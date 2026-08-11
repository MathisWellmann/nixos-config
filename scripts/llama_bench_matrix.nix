# Benchmark throughput of the `localModels` from `hosts/desg0/constants.nix`
# across parallel-sequence (concurrency) levels up to 256 using
# `llama-batched-bench` from the system llama.cpp (same CUDA build as the
# `llama-cpp` service). Models are used from the local HF cache (`--offline`);
# uncached models are skipped.
{pkgs, ...}: let
  const = import ../hosts/desg0/constants.nix;
  models = builtins.concatStringsSep " " (map (m: "\"${m}\"") const.localModels);
in
  pkgs.writeShellScriptBin "llama_bench_matrix" ''
    set -u
    export HUGGINGFACE_HUB_CACHE="''${HUGGINGFACE_HUB_CACHE:-$HOME/.cache/llama-cpp}"
    BENCH="''${BENCH:-llama-batched-bench}"

    NPP=512 # prompt tokens per sequence
    NTG=128 # generated tokens per sequence
    LEVELS="''${LEVELS:-1 2 4 8 16 32 64 128 256}"

    outdir="$(mktemp -d /tmp/llama_bench_matrix.XXXX)"
    results="$outdir/results.tsv"
    echo -e "model\tnpl\ts_pp\ts_tg\ts_total" >"$results"
    echo "Logs and results in: $outdir" >&2

    for model in ${models}; do
      echo "=== $model ===" >&2
      for npl in $LEVELS; do
        ctx=$((npl * (NPP + NTG)))
        log="$outdir/$(echo "$model" | tr '/:' '__')_npl$npl.log"
        echo "  npl=$npl (ctx=$ctx)..." >&2
        if ! "$BENCH" -hf "$model" --offline -ngl 999 -fa on \
          -c "$ctx" -b 2048 -ub 512 \
          -npp "$NPP" -ntg "$NTG" -npl "$npl" >"$log" 2>&1; then
          if [ "$npl" = 1 ]; then
            echo "  model unavailable or failed to load, skipping" >&2
          else
            echo "  failed (likely OOM), skipping higher levels" >&2
          fi
          break
        fi
        row="$(grep -E '^\|\s+[0-9]+' "$log" | tail -1)"
        s_pp="$(echo "$row" | awk -F'|' '{gsub(/ /,"",$7); print $7}')"
        s_tg="$(echo "$row" | awk -F'|' '{gsub(/ /,"",$9); print $9}')"
        s_tot="$(echo "$row" | awk -F'|' '{gsub(/ /,"",$11); print $11}')"
        echo -e "$model\t$npl\t$s_pp\t$s_tg\t$s_tot" >>"$results"
      done
    done

    echo
    echo "## Generation throughput S_TG (tok/s, aggregate over all sequences)"
    ${pkgs.gawk}/bin/awk -F'\t' -v levels="$LEVELS" '
      NR>1 { v[$1"|"$2]=$4; m[$1]=1 }
      END {
        n=split(levels, L, " ")
        printf "%-55s", "model"; for(i=1;i<=n;i++) printf "%10s", L[i]; print ""
        for (mod in m) {
          printf "%-55s", mod
          for(i=1;i<=n;i++){ k=mod"|"L[i]; printf "%10s", (k in v)?v[k]:"-" }
          print ""
        }
      }' "$results"

    echo
    echo "## Total throughput S (tok/s, prompt+gen)"
    ${pkgs.gawk}/bin/awk -F'\t' -v levels="$LEVELS" '
      NR>1 { v[$1"|"$2]=$5; m[$1]=1 }
      END {
        n=split(levels, L, " ")
        printf "%-55s", "model"; for(i=1;i<=n;i++) printf "%10s", L[i]; print ""
        for (mod in m) {
          printf "%-55s", mod
          for(i=1;i<=n;i++){ k=mod"|"L[i]; printf "%10s", (k in v)?v[k]:"-" }
          print ""
        }
      }' "$results"

    echo
    echo "Raw results: $results"
  ''
