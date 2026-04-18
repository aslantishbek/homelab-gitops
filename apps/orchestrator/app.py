from fastapi import FastAPI, Request, Header
from fastapi.responses import JSONResponse, StreamingResponse
from openai import AsyncOpenAI
import os, json, asyncio, time, uuid

app = FastAPI(title="AI Orchestrator")

LITELLM_URL = os.getenv("LITELLM_URL", "http://litellm.ai.svc.cluster.local:4000/v1")
LITELLM_KEY = os.getenv("LITELLM_KEY", "anything")

client = AsyncOpenAI(base_url=LITELLM_URL, api_key=LITELLM_KEY)

# Model tiers
WORKER_MODELS = {
    "fast":    "qwen3.5-27b",
    "default": "qwen3.5-35b",
    "heavy":   "gemma4-31b",
    "code":    "qwen3-coder-30b",
}
REVIEWER_MODELS = {
    "fast":    "claude-haiku",
    "default": "claude-sonnet",
    "heavy":   "claude-opus",
    "gemini":  "gemini-2.5-pro",
}

REVIEW_PROMPT = (
    "You are a senior reviewer. A local AI model produced the response below. "
    "If it is accurate and complete, return it EXACTLY as-is. "
    "If it has errors or is incomplete, silently fix and return only the corrected response. "
    "Never add meta-commentary like 'The response is correct' — return only the final answer."
)

def parse_tier(model_name: str) -> tuple[str, str]:
    """Map model name to (worker, reviewer) pair."""
    mapping = {
        "orchestrated":         (WORKER_MODELS["default"], REVIEWER_MODELS["default"]),
        "orchestrated-fast":    (WORKER_MODELS["fast"],    REVIEWER_MODELS["fast"]),
        "orchestrated-heavy":   (WORKER_MODELS["heavy"],   REVIEWER_MODELS["heavy"]),
        "orchestrated-code":    (WORKER_MODELS["code"],    REVIEWER_MODELS["default"]),
        "orchestrated-gemini":  (WORKER_MODELS["default"], REVIEWER_MODELS["gemini"]),
    }
    return mapping.get(model_name, (WORKER_MODELS["default"], REVIEWER_MODELS["default"]))

@app.get("/v1/models")
async def list_models():
    models = [
        "orchestrated", "orchestrated-fast", "orchestrated-heavy",
        "orchestrated-code", "orchestrated-gemini"
    ]
    return {
        "object": "list",
        "data": [{"id": m, "object": "model", "created": 0, "owned_by": "orchestrator"} for m in models]
    }

@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    body = await request.json()
    messages = body.get("messages", [])
    model_name = body.get("model", "orchestrated")
    stream = body.get("stream", False)

    worker_model, reviewer_model = parse_tier(model_name)

    # Step 1: local model generates
    worker_resp = await client.chat.completions.create(
        model=worker_model,
        messages=messages,
        temperature=body.get("temperature", 0.7),
    )
    worker_answer = worker_resp.choices[0].message.content

    # Step 2: reviewer checks
    review_messages = [
        {"role": "system", "content": REVIEW_PROMPT},
        *messages,
        {"role": "assistant", "content": worker_answer},
        {"role": "user", "content": "Review the response above and return the final answer."},
    ]
    reviewer_resp = await client.chat.completions.create(
        model=reviewer_model,
        messages=review_messages,
        temperature=0.2,
    )
    final_answer = reviewer_resp.choices[0].message.content

    completion_id = f"chatcmpl-{uuid.uuid4().hex[:8]}"
    now = int(time.time())

    if stream:
        async def event_stream():
            chunk = {
                "id": completion_id, "object": "chat.completion.chunk",
                "created": now, "model": model_name,
                "choices": [{"index": 0, "delta": {"role": "assistant", "content": final_answer}, "finish_reason": None}]
            }
            yield f"data: {json.dumps(chunk)}\n\n"
            done = {
                "id": completion_id, "object": "chat.completion.chunk",
                "created": now, "model": model_name,
                "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}]
            }
            yield f"data: {json.dumps(done)}\n\n"
            yield "data: [DONE]\n\n"
        return StreamingResponse(event_stream(), media_type="text/event-stream")

    return {
        "id": completion_id, "object": "chat.completion",
        "created": now, "model": model_name,
        "choices": [{
            "index": 0,
            "message": {"role": "assistant", "content": final_answer},
            "finish_reason": "stop"
        }],
        "usage": {
            "prompt_tokens": worker_resp.usage.prompt_tokens + reviewer_resp.usage.prompt_tokens,
            "completion_tokens": reviewer_resp.usage.completion_tokens,
            "total_tokens": worker_resp.usage.total_tokens + reviewer_resp.usage.total_tokens,
        }
    }

@app.get("/health")
async def health():
    return {"status": "ok"}
