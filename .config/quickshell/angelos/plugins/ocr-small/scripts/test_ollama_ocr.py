#!/usr/bin/env python3
import io
import json
import os
import sys
import tempfile
import unittest
from unittest.mock import patch

import ollama_ocr as ocr


class OCRTests(unittest.TestCase):
    def response(self, result):
        return io.BytesIO(json.dumps(result).encode())

    @patch("ollama_ocr.urllib.request.build_opener")
    def test_request_and_output(self, opener):
        opener.return_value.open.return_value = self.response({
            "done": True, "done_reason": "stop", "message": {"content": "Привет\nмир"},
        })
        self.assertEqual(ocr.recognize(b"image"), "Привет\nмир")
        request = opener.return_value.open.call_args.args[0]
        data = json.loads(request.data)
        self.assertEqual(request.full_url, "http://127.0.0.1:11434/api/chat")
        self.assertEqual(data["model"], "glm-ocr")
        self.assertEqual(data["messages"][0]["images"], ["aW1hZ2U="])

    @patch("ollama_ocr.urllib.request.build_opener")
    def test_empty_and_truncated_are_errors(self, opener):
        for result in (
            {"done": True, "message": {"content": "  "}},
            {"done": True, "done_reason": "length", "message": {"content": "partial"}},
        ):
            opener.return_value.open.return_value = self.response(result)
            with self.assertRaises(RuntimeError):
                ocr.recognize(b"image")

    def run_pick(self, responses, recognition=None):
        with tempfile.TemporaryDirectory() as runtime, \
             patch.dict(os.environ, {"XDG_RUNTIME_DIR": runtime}), \
             patch.object(sys, "argv", ["ocr-region-local"]), \
             patch("ollama_ocr.subprocess.run", side_effect=responses) as run, \
             patch("ollama_ocr.notify"), \
             patch("ollama_ocr.show_card", return_value=True), \
             patch("ollama_ocr.recognize", side_effect=recognition) as recognize:
            result = ocr.main()
            return result, run.call_args_list, recognize.call_count

    def test_selection_cancelled(self):
        from subprocess import CompletedProcess
        result, calls, count = self.run_pick([CompletedProcess([], 1, "", "")])
        self.assertEqual((result, len(calls), count), (0, 1, 0))

    def test_success_copies_only_recognized_text(self):
        from subprocess import CompletedProcess
        responses = [CompletedProcess([], 0, "10,20 100x30\n", ""),
                     CompletedProcess([], 0, b"image", b""), CompletedProcess([], 0)]
        result, calls, count = self.run_pick(responses, lambda image: "Текст\n42")
        self.assertEqual((result, len(calls), count), (0, 3, 1))
        self.assertEqual(calls[1].args[0], ["grim", "-g", "10,20 100x30", "-"])
        self.assertEqual(calls[2].args[0][0], "wl-copy")
        self.assertEqual(calls[2].kwargs["input"], "Текст\n42".encode())

    def test_failure_does_not_touch_clipboard(self):
        from subprocess import CompletedProcess
        responses = [CompletedProcess([], 0, "10,20 100x30", ""),
                     CompletedProcess([], 0, b"image", b"")]
        result, calls, count = self.run_pick(responses, RuntimeError("unavailable"))
        self.assertEqual((result, len(calls), count), (1, 2, 1))


if __name__ == "__main__":
    unittest.main()
