#!/usr/bin/env python3
"""Concurrency sweep against a vLLM server (OpenAI-compatible API).

Usage: vllm_bench.py [base_url] [model] [levels_csv]
Workload per request: fixed ~128-token prompt, greedy, 128 output tokens.
Prints a per-level table plus METRIC lines for the primary metric
(peak aggregate output tok/s) and per-level values.
"""
import asyncio
import json
import statistics
import sys
import time

import httpx

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000/v1"
MODEL = sys.argv[2] if len(sys.argv) > 2 else "Qwen/Qwen3.8-27B-FP8"
LEVELS = [int(x) for x in sys.argv[3].split(",")] if len(sys.argv) > 3 else [1, 2, 4, 8, 16, 32, 64, 128]
MAX_TOKENS = 128
# ponytail: fixed repeated sentence ≈128 tokens, close enough for a sweep
PROMPT = ("The quick brown fox jumps over the lazy dog. " * 16).strip()

HDRS = {"Authorization": f"Bearer {sys.argv[4] if len(sys.argv) > 4 else 'sk-dummy'}"}


async def one_request(client: httpx.AsyncClient) -> dict:
    t0 = time.perf_counter()
    ttft = None
    n_out = 0
    async with client.stream(
        "POST",
        f"{BASE}/chat/completions",
        json={
            "model": MODEL,
            "messages": [{"role": "user", "content": PROMPT}],
            "max_tokens": MAX_TOKENS,
            "temperature": 0,
            "stream": True,
            "stream_options": {"include_usage": True},
        },
        headers=HDRS,
    ) as resp:
        if resp.status_code != 200:
            body = await resp.aread()
            raise RuntimeError(f"HTTP {resp.status_code}: {body[:200]!r}")
        async for line in resp.aiter_lines():
            if not line.startswith("data:"):
                continue
            data = line[5:].strip()
            if data == "[DONE]":
                break
            chunk = json.loads(data)
            if chunk.get("usage"):
                n_out = chunk["usage"]["completion_tokens"] or n_out
            if chunk.get("choices"):
                delta = chunk["choices"][0].get("delta") or {}
                if delta.get("content") or delta.get("reasoning") or delta.get("reasoning_content"):
                    if ttft is None:
                        ttft = time.perf_counter() - t0
                    n_out += 1
    return {"ttft": ttft, "total": time.perf_counter() - t0, "out": n_out}


async def sweep_level(level: int) -> dict:
    timeout = httpx.Timeout(600.0, connect=10.0)
    async with httpx.AsyncClient(timeout=timeout) as client:
        t0 = time.perf_counter()
        results = await asyncio.gather(*[
            one_request(client) for _ in range(level)
        ], return_exceptions=True)
    wall = time.perf_counter() - t0
    ok = [r for r in results if not isinstance(r, Exception)]
    errs = [r for r in results if isinstance(r, Exception)]
    if not ok:
        return {"level": level, "errors": level, "wall": wall, "first_err": str(errs[0])}
    tot_out = sum(r["out"] for r in ok)
    ttfts = sorted(r["ttft"] for r in ok if r["ttft"])
    totals = sorted(r["total"] for r in ok)
    return {
        "level": level,
        "errors": len(errs),
        "wall": wall,
        "out_tok_s": tot_out / wall,
        "mean_ttft": statistics.mean(ttfts),
        "p95_ttft": ttfts[int(0.95 * (len(ttfts) - 1))] if len(ttfts) > 1 else ttfts[0],
        "mean_total": statistics.mean(totals),
        "p95_total": totals[int(0.95 * (len(totals) - 1))] if len(totals) > 1 else totals[0],
        "first_err": str(errs[0]) if errs else None,
    }


def main():
    print(f"model={MODEL} base={BASE} prompt≈128tok max_tokens={MAX_TOKENS} levels={LEVELS}")
    stats = []
    for lvl in LEVELS:
        s = asyncio.run(sweep_level(lvl))
        stats.append(s)
        if "out_tok_s" in s:
            print(
                f"  c={s['level']:>4}  {s['out_tok_s']:8.1f} out_tok/s  "
                f"wall={s['wall']:7.2f}s  ttft_mean={s['mean_ttft']:7.3f}s  "
                f"ttft_p95={s['p95_ttft']:7.3f}s  total_mean={s['mean_total']:7.3f}s  "
                f"total_p95={s['p95_total']:7.3f}s  err={s['errors']}"
            )
        else:
            print(f"  c={s['level']:>4}  FAILED err={s['errors']} wall={s['wall']:.2f}s {s['first_err']}")
            break
    ok = [s for s in stats if "out_tok_s" in s]
    peak = max(ok, key=lambda s: s["out_tok_s"]) if ok else None
    if peak:
        print(f"METRIC peak_out_tok_s={peak['out_tok_s']:.1f}")
        print(f"METRIC peak_at_concurrency={peak['level']}")
    for s in ok:
        print(f"METRIC out_tok_s_c{s['level']}={s['out_tok_s']:.1f}")
        print(f"METRIC total_p95_s_c{s['level']}={s['p95_total']:.3f}")
    errs = sum(s.get("errors", 0) for s in stats)
    print(f"METRIC total_errors={errs}")


if __name__ == "__main__":
    main()
