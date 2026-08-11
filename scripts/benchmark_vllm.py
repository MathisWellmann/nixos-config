#!/usr/bin/env python3
"""vLLM Inference Benchmark Tool

Usage:
  python3 scripts/benchmark_vllm.py [--url http://127.0.0.1:8000/v1/chat/completions]
                                    [--model nvidia/Qwen3.6-35B-A3B-NVFP4]
                                    [--concurrencies 2,4,8,16,32,64,128,256]
                                    [--max-tokens 128]
"""

import argparse
import asyncio
import json
import statistics
import time
import aiohttp


async def send_request(session, url, model, prompt, max_tokens, req_id):
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": max_tokens,
        "stream": True,
        "stream_options": {"include_usage": True},
        "temperature": 0.6,
    }

    start_time = time.perf_counter()
    ttft = None
    output_tokens = 0

    try:
        async with session.post(url, json=payload, timeout=120) as resp:
            if resp.status != 200:
                text = await resp.text()
                print(f"Req {req_id} Error {resp.status}: {text[:100]}")
                return None

            async for line in resp.content:
                line_str = line.decode("utf-8").strip()
                if line_str.startswith("data: ") and line_str != "data: [DONE]":
                    now = time.perf_counter()
                    if ttft is None:
                        ttft = now - start_time
                    try:
                        data = json.loads(line_str[6:])
                        usage = data.get("usage")
                        if usage and usage.get("completion_tokens"):
                            output_tokens = usage["completion_tokens"]
                    except Exception:
                        pass

    except Exception as e:
        print(f"Req {req_id} failed: {e}")
        return None

    end_time = time.perf_counter()
    total_time = end_time - start_time

    return {
        "total_time": total_time,
        "ttft": ttft or total_time,
        "output_tokens": output_tokens,
        "tps": (
            (output_tokens / (end_time - (start_time + (ttft or 0))))
            if (output_tokens > 1 and ttft)
            else (output_tokens / total_time)
            if total_time > 0
            else 0
        ),
    }


async def run_benchmark_level(session, url, model, prompt, max_tokens, concurrency, req_count):
    total_reqs = max(concurrency * 2, req_count)
    print(f"\n--- Running Concurrency: {concurrency} ({total_reqs} requests total) ---")

    semaphore = asyncio.Semaphore(concurrency)

    async def worker(req_id):
        async with semaphore:
            return await send_request(session, url, model, prompt, max_tokens, req_id)

    t0 = time.perf_counter()
    tasks = [worker(i) for i in range(total_reqs)]
    results = await asyncio.gather(*tasks)
    t1 = time.perf_counter()

    valid = [r for r in results if r is not None]
    if not valid:
        print(f"Concurrency {concurrency}: All requests failed.")
        return None

    elapsed = t1 - t0
    total_output_tokens = sum(r["output_tokens"] for r in valid)
    system_tps = total_output_tokens / elapsed if elapsed > 0 else 0
    avg_ttft = statistics.mean([r["ttft"] * 1000 for r in valid])
    avg_req_time = statistics.mean([r["total_time"] for r in valid])
    avg_user_tps = statistics.mean([r["tps"] for r in valid])

    res_summary = {
        "concurrency": concurrency,
        "total_reqs": len(valid),
        "elapsed_sec": round(elapsed, 2),
        "system_tps": round(system_tps, 1),
        "avg_user_tps": round(avg_user_tps, 1),
        "avg_ttft_ms": round(avg_ttft, 1),
        "avg_latency_sec": round(avg_req_time, 2),
    }
    print(
        f"Result: {system_tps:.1f} system tok/s | Avg TTFT: {avg_ttft:.1f}ms | Avg Latency: {avg_req_time:.2f}s"
    )
    return res_summary


async def main():
    parser = argparse.ArgumentParser(description="vLLM Inference Server Benchmark")
    parser.add_argument("--url", default="http://127.0.0.1:8000/v1/chat/completions")
    parser.add_argument("--model", default="nvidia/Qwen3.6-35B-A3B-NVFP4")
    parser.add_argument("--prompt", default="Write a Python script that calculates prime numbers up to 1000 and explains the Sieve of Eratosthenes.")
    parser.add_argument("--concurrencies", default="2,4,8,16,32")
    parser.add_argument("--max-tokens", type=int, default=128)
    parser.add_argument("--requests-per-level", type=int, default=16)
    args = parser.parse_args()

    concurrencies = [int(c.strip()) for c in args.concurrencies.split(",")]

    print(f"Benchmarking vLLM server at {args.url}")
    print(f"Model: {args.model}")

    summaries = []
    async with aiohttp.ClientSession() as session:
        for c in concurrencies:
            res = await run_benchmark_level(
                session, args.url, args.model, args.prompt, args.max_tokens, c, args.requests_per_level
            )
            if res:
                summaries.append(res)
            await asyncio.sleep(1)

    print("\n" + "=" * 80)
    print("BENCHMARK SUMMARY")
    print("=" * 80)
    print(
        f"{'Concurrency':<12} | {'System TPS':<12} | {'User TPS':<12} | {'Avg TTFT (ms)':<14} | {'Avg Latency (s)':<15}"
    )
    print("-" * 80)
    for s in summaries:
        print(
            f"{s['concurrency']:<12} | {s['system_tps']:<12.1f} | {s['avg_user_tps']:<12.1f} | {s['avg_ttft_ms']:<14.1f} | {s['avg_latency_sec']:<15.2f}"
        )
    print("=" * 80)


if __name__ == "__main__":
    asyncio.run(main())
