import json
import unittest

from android_server import ANDROID_PREFIX, payload_from, result_for, send_result


class AndroidResponderTests(unittest.TestCase):
    def test_durable_replay_and_status_reuse_result(self):
        journal = {}
        req = {"run": "r", "request": "q", "command": "LIST_RECENT"}
        expected = {"size": 2963, "sha256": "a" * 64}
        first = result_for(req, journal, expected)
        restored = json.loads(json.dumps(journal))
        duplicate = result_for(req, restored, {"size": 999, "sha256": "b" * 64})
        self.assertTrue(duplicate["duplicate"])
        self.assertEqual(duplicate["sha256"], first["sha256"])
        self.assertEqual(duplicate["prepared_count"], 1)
        status = result_for({"run": "r2", "request": "q2", "command": "GET_STATUS", "result_for": "q"}, restored, expected)
        self.assertEqual(status["sha256"], first["sha256"])
        self.assertEqual(status["request"], "q2")
        conflict = result_for({**req, "command": "GET_STATUS"}, restored, expected)
        self.assertEqual(conflict["status"], "conflict")
        self.assertEqual(restored["q"]["result"], first)

    def test_response_uses_android_prefix_and_new_transport_id(self):
        class Bot:
            def __init__(self): self.calls = []
            def api(self, method, **args):
                self.calls.append((method, args))
                return [{"conversation_message_id": 10}]
        bot = Bot()
        for _ in range(2):
            send_result(bot, 2000000001, {"status": "ready"}, "doc1_2")
        first, second = [call[1] for call in bot.calls]
        self.assertTrue(first["message"].startswith(ANDROID_PREFIX))
        self.assertEqual(first["peer_ids"], 2000000001)
        self.assertEqual(first["attachment"], "doc1_2")
        self.assertNotEqual(first["random_id"], second["random_id"])

    def test_only_client_envelopes_in_bound_chat_and_identity_are_accepted(self):
        payload = {"role": "client", "run": "r", "request": "q"}
        message = {"from_id": -42, "peer_id": 2000000001, "text": ANDROID_PREFIX + json.dumps(payload)}
        self.assertEqual(payload_from(message, 42, 2000000001), payload)
        self.assertIsNone(payload_from(message, 43, 2000000001))
        self.assertIsNone(payload_from(message, 42, 2000000002))
        self.assertIsNone(payload_from({**message, "text": ANDROID_PREFIX + '{bad'}, 42, 2000000001))


if __name__ == '__main__':
    unittest.main()
