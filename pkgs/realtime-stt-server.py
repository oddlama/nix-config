#!/usr/bin/env python3

import argparse
import json
import logging
import numpy as np
import queue
import socket
import struct
import time
import sys
import threading

def send_message(sock, message):
    message_str = json.dumps(message)
    message_bytes = message_str.encode("utf-8")
    message_length = len(message_bytes)
    sock.sendall(struct.pack("!I", message_length))
    sock.sendall(message_bytes)

def recv_message(sock):
    length_bytes = sock.recv(4)
    if not length_bytes or len(length_bytes) == 0:
        return None
    message_length = struct.unpack("!I", length_bytes)[0]
    if message_length & 0x80000000 != 0:
        # Raw audio data
        message_length &= ~0x80000000
        message_bytes = sock.recv(message_length)
        return message_bytes

    message_bytes = sock.recv(message_length)
    message_str = message_bytes.decode("utf-8")
    return json.loads(message_str)

class Client:
    def __init__(self, tag, conn):
        self.tag = tag
        self.conn = conn
        self.thread = threading.current_thread()
        self.mode = None
        self.is_true_client = False
        self.waiting = False
        self.queue = queue.Queue()

clients = {}
active_client = None
model_lock = threading.Lock()

def publish(obj, client=None):
    msg = json.dumps(obj)
    if client is None:
        for c in clients.values():
            if c.mode == "status":
                c.queue.put(msg)
    else:
        client.queue.put(msg)

def refresh_status(client=None):
    publish(dict(refresh_status=True), client=client)

def handle_client(conn, addr):
    global recorder
    global active_client
    tag = f"{addr[0]}:{addr[1]}"
    client = Client(tag, conn)
    clients[addr] = client

    try:
        logger.info(f'{tag} Connected to client')
        init = recv_message(conn)
        logger.info(f'{tag} Client requested mode {init["mode"]}')
        client.mode = init["mode"]
        client.is_true_client = init["mode"] == "stream"

        if init["mode"] == "status":
            refresh_status(client) # refresh once after startup

            while True:
                message = json.loads(client.queue.get())

                if "refresh_status" in message and message["refresh_status"] == True:
                    n_clients = len(list(filter(lambda x: x.is_true_client, clients.values())))
                    n_waiting = len(list(filter(lambda x: x.is_true_client and x.waiting, clients.values())))
                    status = {
                        "clients": n_clients,
                        "waiting": n_waiting,
                    }
                    send_message(conn, status)
                    client.queue.task_done()
        else:
            logger.info(f'{tag} Acquiring lock')
            client.waiting = True
            refresh_status()
            send_message(conn, dict(status="waiting for lock"))

            with model_lock:
                active_client = client
                client.waiting = False
                refresh_status()
                send_message(conn, dict(status="lock acquired"))
                recorder.start()

                def send_queue():
                    try:
                        while True:
                            message = client.queue.get()
                            if message is None:
                                return
                            send_message(conn, message)
                            client.queue.task_done()
                    except (OSError, ConnectionError):
                        logger.info(f"{tag} error in send queue: connection closed?")

                sender_thread = threading.Thread(target=send_queue)
                sender_thread.daemon = True
                sender_thread.start()

                try:
                    while True:
                        msg = recv_message(conn)
                        if msg is None:
                            break

                        if isinstance(msg, bytes):
                            recorder.feed_audio(msg)
                            continue

                        if "action" in msg and msg["action"] == "flush":
                            logger.info(f"{tag} flushing on client request")
                            # input some silence
                            for i in range(10):
                                recorder.feed_audio(bytes(1000))
                            recorder.stop()
                            logger.info(f"{tag} flushed")
                            continue
                        else:
                            logger.info(f"{tag} error in recv: invalid message: {msg}")
                            continue
                except (OSError, ConnectionError):
                    logger.info(f"{tag} error in recv: connection closed?")
                finally:
                    client.queue.put(None)
                    active_client = None
                    recorder.stop()
                    sender_thread.join()
    except Exception as e:
        import traceback
        traceback.print_exc()
        logger.error(f'{tag} Error handling client: {e}')
    finally:
        refresh_status()
        del clients[addr]
        conn.close()
        logger.info(f'{tag} Connection closed')

if __name__ == "__main__":
    logging.basicConfig(format="%(levelname)s %(message)s")
    logger = logging.getLogger("realtime-stt-server")
    logger.setLevel(logging.DEBUG)
    #logging.getLogger().setLevel(logging.DEBUG)

    parser = argparse.ArgumentParser()
    parser.add_argument("--host", type=str, default='localhost')
    parser.add_argument("--port", type=int, default=43007)
    args = parser.parse_args()

    logger.info("Importing runtime")
    from RealtimeSTT import AudioToTextRecorder

    def text_detected(ts):
        text, segments = ts
        global active_client
        if active_client is not None:
            segments = [x._asdict() for x in segments]
            active_client.queue.put(dict(kind="realtime", text=text, segments=segments))

    recorder_ready = threading.Event()
    recorder_config = {
        'init_logging': False,

        'use_microphone': False,
        'spinner': False,
        'model': 'large-v3',
        'return_segments': True,
        #'language': 'en',

        'silero_sensitivity': 0.4,
        'webrtc_sensitivity': 2,
        'post_speech_silence_duration': 0.7,
        'min_length_of_recording': 0.0,
        'min_gap_between_recordings': 0,

        'enable_realtime_transcription': True,
        'realtime_processing_pause': 0,
        'realtime_model_type': 'base',

        'on_realtime_transcription_stabilized': text_detected,
    }

    def recorder_thread():
        global recorder
        global active_client
        logger.info("Initializing RealtimeSTT...")
        recorder = AudioToTextRecorder(**recorder_config)
        logger.info("AudioToTextRecorder ready")
        recorder_ready.set()
        try:
            while not recorder.is_shut_down:
                text, segments = recorder.text()
                if text == "":
                    continue
                if active_client is not None:
                    segments = [x._asdict() for x in segments]
                    active_client.queue.put(dict(kind="result", text=text, segments=segments))
        except (OSError, EOFError) as e:
            logger.info(f"recorder thread failed: {e}")
            return

    recorder_thread = threading.Thread(target=recorder_thread)
    recorder_thread.start()
    recorder_ready.wait()

    logger.info(f'Starting server on {args.host}:{args.port}')
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((args.host, args.port))
        s.listen()
        logger.info(f'Server ready to accept connections')

        try:
            while True:
                # Accept incoming connection
                conn, addr = s.accept()
                conn.setblocking(True)

                # Create a new thread to handle the client
                client_thread = threading.Thread(target=handle_client, args=(conn, addr))
                client_thread.daemon = True # die with main thread
                client_thread.start()

                # Note: The main thread continues to accept new connections
        except KeyboardInterrupt:
            logger.info(f'Received shutdown request')

        for c in clients.values():
            try:
                c.conn.close()
            except (OSError, ConnectionError):
                pass
        try:
            s.close()
        except (OSError, ConnectionError):
            pass

        recorder.shutdown()

    logger.info('Server terminated')
