"""bash buddy — an intelligent IPython shell.

Reproduces https://nathancooper.io/blog/2026-08-10-ipython-is-all-you-need with
the inference provider pointed at the local sglang server (desg0:8000).

Loaded automatically as an IPython startup file (see home/python.nix).
"""

# get_ipython() is a builtin in IPython startup files (importing it only works in Jupyter)
_ipython = get_ipython()
_ipython.run_line_magic("rehashx", "")
_ipython.run_line_magic("load_ext", "ipythonng")
_ipython.run_line_magic("matplotlib", "inline")

# --- inference provider: local sglang server (OpenAI-compatible) -----------
import os

mdl = os.environ.get("BASH_BUDDY_MODEL", "RadixArk/Qwen3.8-27B-NVFP4")
base_url = "http://desg0:8000/v1"
api_key = "sk-local"  # sglang runs without auth; fastllm requires a non-empty key
sp = "You are a helpful assistant living in a user's IPython shell. Use markdown syntax for styling your responses."

import io
import sys
from base64 import b64decode

from fastcore.xtras import clean_cli_output
from fastllm.chat import AsyncChat, contents, mk_msgs
from rich.markdown import Markdown
from safecmd import bash
from safepyrun.core import RunPython

python = RunPython()


def build_ctx(n=5):
    """Walk the last n cells, grabbing sources from In and any outputs,
    images, or errors from the history manager."""
    hm, parts = get_ipython().history_manager, []
    stop = len(In) - 1
    for i in range(max(1, stop - n), stop):
        src = In[i].strip()
        if not src:
            continue
        parts.append(f"<code>{src}</code>")
        for o in hm.outputs.get(i, []):
            b = o.bundle
            if "stream" in b:
                parts.append(f"<output>{clean_cli_output(''.join(b['stream']))}</output>")
            elif "image/png" in b:
                parts.append(b["image/png"] if isinstance(b["image/png"], bytes) else b64decode(b["image/png"]))
            elif "text/plain" in b:
                parts.append(f"<output>{clean_cli_output(b['text/plain'])}</output>")
        if (e := hm.exceptions.get(i)):
            parts.append(f"<error>{e['ename']}: {e['evalue']}</error>")
    return parts


async def safe_python(code: str):
    "Execute Python code, capturing stdout, stderr, and return value — never raises"
    buf = io.StringIO()
    old_out, old_err = sys.stdout, sys.stderr
    try:
        sys.stdout = sys.stderr = buf
        result = await python(code)
        output = buf.getvalue()
        if result is not None:
            output += (("\n" if output else "") + str(result))
        return output or "(no output)"
    except Exception as e:
        output = buf.getvalue()
        return f"{output}Error: {type(e).__name__}: {e}"
    finally:
        sys.stdout, sys.stderr = old_out, old_err


async def chat(prompt):
    "Ask bash buddy: the last 20 cells as context, safe bash/python tools"
    c = AsyncChat(mdl, sp=sp, tools=[bash, safe_python], base_url=base_url, api_key=api_key)
    msg = mk_msgs([build_ctx(20) + [f"<user-request>{prompt}</user-request>"]])[0]
    return Markdown(contents(await c(msg, max_steps=20)).text)


def transform_prompts(lines):
    """Make `:query` an alias for `await chat('query')`"""
    if not lines or not lines[0].lstrip().startswith(":"):
        return lines
    prompt = "".join([lines[0].lstrip()[1:], *lines[1:]]).strip()
    return [f"await chat({prompt!r})\n"]


get_ipython().input_transformer_manager.cleanup_transforms.insert(0, transform_prompts)
