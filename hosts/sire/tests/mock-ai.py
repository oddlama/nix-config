"""Loopback-only protocol fixtures, deliberately not inference backends."""
import io
import json
import threading
import wave
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

lock = threading.Lock()


class Backend(BaseHTTPRequestHandler):
    def reply(self, body, content_type="application/json", status=200):
        if not isinstance(body, bytes):
            body = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def record(self, body=b""):
        with lock, open("/run/mock-ai/requests.jsonl", "a") as output:
            output.write(json.dumps({
                "port": self.server.server_port,
                "path": self.path,
                "authorization": self.headers.get("Authorization"),
                "body": body.decode(),
            }) + "\n")
        assert not self.headers.get("Authorization"), "gateway leaked a client/upstream token"

    def do_GET(self):
        self.record()
        assert self.server.server_port == 11438
        assert self.path.startswith("/v1/artifacts/")
        self.reply(b"test-image", "image/png")

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        self.record(body)
        port = self.server.server_port
        if port == 11434:
            assert self.path == "/v1/chat/completions", self.path
            request = json.loads(body)
            assert request["model"] == "orcarouter-qwen38-27b"
            base = {"id": "chatcmpl-test", "created": 1, "model": request["model"]}
            usage = {"prompt_tokens": 7, "completion_tokens": 5, "total_tokens": 12}
            if request.get("stream"):
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream")
                self.end_headers()
                for choices, extra in [
                    ([{"index": 0, "delta": {"role": "assistant", "content": "Hello"},
                       "finish_reason": None}], {}),
                    ([{"index": 0, "delta": {}, "finish_reason": "stop"}], {}),
                    ([], {"usage": usage}),
                ]:
                    chunk = {**base, "object": "chat.completion.chunk", "choices": choices, **extra}
                    self.wfile.write(("data: " + json.dumps(chunk) + "\n\n").encode())
                    self.wfile.flush()
                self.wfile.write(b"data: [DONE]\n\n")
            else:
                self.reply({**base, "object": "chat.completion", "usage": usage, "choices": [
                    {"index": 0, "message": {"role": "assistant", "content": "Hello"},
                     "finish_reason": "stop"}
                ]})
        elif port == 11435:
            assert self.path == "/v1/audio/speech", self.path
            request = json.loads(body)
            assert request["model"] == "omnivoice-tts"
            assert request["input"] == "Hello"
            assert request["voice"] == "alloy"
            assert request["language"] == "en"  # Preserve OmniVoice's extensions.
            audio = io.BytesIO()
            with wave.open(audio, "wb") as output:
                output.setnchannels(1)
                output.setsampwidth(2)
                output.setframerate(24000)
                output.writeframes(b"\x00\x00" * 240)
            self.reply(audio.getvalue(), "audio/wav")
        else:
            assert port == 11438
            if self.path == "/v1/parse/async_check":
                assert b"task_id=test-task" in body
                self.reply({"data": {"status": "success"}})
            else:
                assert self.path in ["/v1/parse/sync", "/v1/parse/async"]
                assert self.headers["Content-Type"].startswith("multipart/form-data")
                assert b"fixture-document" in body
                self.reply({"data": {"task_id": "test-task", "image": "/v1/artifacts/job/image.png"}})


for port in [11434, 11435, 11438]:
    server = ThreadingHTTPServer(("127.0.0.1", port), Backend)
    threading.Thread(target=server.serve_forever, daemon=True).start()
threading.Event().wait()
