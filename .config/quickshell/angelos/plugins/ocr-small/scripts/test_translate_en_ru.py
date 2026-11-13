#!/usr/bin/env python3
import unittest
from unittest.mock import patch

import translate_en_ru as t


class TranslateTests(unittest.TestCase):
    @patch("translate_en_ru.processors")
    @patch("translate_en_ru.translator")
    def test_translation_uses_ct2(self, translator, processors):
        src = type("Src", (), {"encode": lambda self, text, out_type: ["The", "clipboard", "is", "ready", ".</s>", "</s>"]})()
        tgt = type("Tgt", (), {"decode": lambda self, tokens: "буфер обмена готов."})()
        processors.return_value = (src, tgt)
        translator.return_value.translate_batch.return_value = [type("Res", (), {"hypotheses": [["буфер", "готов."]]})()]
        self.assertEqual(t.translate("The clipboard is ready."), "буфер обмена готов.")

    def test_chunks_keep_paragraphs(self):
        self.assertEqual(list(t.chunks("A.\n\nB!")), ["A.", "", "B!"])


if __name__ == "__main__":
    unittest.main()
