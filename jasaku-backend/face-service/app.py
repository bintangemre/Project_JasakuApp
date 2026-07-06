import io
import base64
import logging
import os

import cv2
import numpy as np
import insightface
from insightface.app import FaceAnalysis
from flask import Flask, request, jsonify
from PIL import Image

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

face_app = FaceAnalysis(
    name="buffalo_l",
    root=os.path.join(os.path.dirname(__file__), "model"),
    providers=["CPUExecutionProvider"],
)
face_app.prepare(ctx_id=-1, det_size=(640, 640))

SIMILARITY_THRESHOLD = float(os.environ.get("SIMILARITY_THRESHOLD", "0.45"))


def load_image(source: str) -> np.ndarray | None:
    """Load image from base64 string, file path, or raw upload bytes."""
    try:
        if source.startswith("data:") or source.startswith("base64,"):
            source = source.split(",", 1)[-1]
            raw = base64.b64decode(source)
            arr = np.frombuffer(raw, np.uint8)
            return cv2.imdecode(arr, cv2.IMREAD_COLOR)
        elif os.path.isfile(source):
            return cv2.imread(source)
        else:
            raw = base64.b64decode(source)
            arr = np.frombuffer(raw, np.uint8)
            return cv2.imdecode(arr, cv2.IMREAD_COLOR)
    except Exception as e:
        logger.warning("Failed to load image: %s", e)
        return None


def get_embedding(img: np.ndarray) -> list[float] | None:
    faces = face_app.get(img)
    if not faces:
        return None
    return faces[0].embedding.tolist()


def cosine_similarity(a: list[float], b: list[float]) -> float:
    a_arr = np.array(a)
    b_arr = np.array(b)
    norm_a = np.linalg.norm(a_arr)
    norm_b = np.linalg.norm(b_arr)
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return float(np.dot(a_arr, b_arr) / (norm_a * norm_b))


@app.route("/compare", methods=["POST"])
def compare():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "Request body must be JSON"}), 400

    ktp_image = data.get("ktp_image")
    selfie_image = data.get("selfie_image")

    if not ktp_image or not selfie_image:
        return jsonify({"error": "ktp_image and selfie_image are required"}), 400

    ktp = load_image(ktp_image)
    selfie = load_image(selfie_image)

    if ktp is None or selfie is None:
        return jsonify({"error": "Failed to decode one or both images"}), 400

    emb_ktp = get_embedding(ktp)
    emb_selfie = get_embedding(selfie)

    if emb_ktp is None or emb_selfie is None:
        return jsonify({"error": "No face detected in one or both images", "similarity": 0}), 200

    similarity = cosine_similarity(emb_ktp, emb_selfie)
    match = similarity >= SIMILARITY_THRESHOLD

    logger.info("Face match: similarity=%.4f, threshold=%.2f, match=%s", similarity, SIMILARITY_THRESHOLD, match)

    return jsonify({
        "similarity": round(similarity, 4),
        "threshold": SIMILARITY_THRESHOLD,
        "match": match,
    })


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5001))
    app.run(host="0.0.0.0", port=port, debug=False)
