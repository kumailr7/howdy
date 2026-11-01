# Passive liveness (anti-spoofing) check for RGB cameras.
#
# Uses the MiniFASNet models from minivision-ai/Silent-Face-Anti-Spoofing
# (Apache-2.0), in the ONNX export published by yakhyo/face-anti-spoofing
# (Apache-2.0). Both models score a crop of the face as live or spoof; their
# "real" probabilities are averaged.
#
# This raises the bar against printed photos and phone/tablet screens. It does
# NOT replace an IR camera: a good replay attack can still pass.

import hashlib

import cv2
import numpy as np

import paths_factory

INPUT_SIZE = 80
# Output classes of the models: 0 = print spoof, 1 = real, 2 = replay spoof
REAL_CLASS = 1

# file name -> (sha256, face crop scale). A file that does not match its hash
# is refused, so a swapped model file cannot change the decision.
MODELS = {
	"MiniFASNetV2.onnx": ("b32929adc2d9c34b9486f8c4c7bc97c1b69bc0ea9befefc380e4faae4e463907", 2.7),
	"MiniFASNetV1SE.onnx": ("ebab7f90c7833fbccd46d3a555410e78d969db5438e169b6524be444862b3676", 4.0),
}


class LivenessError(Exception):
	"""The liveness check could not be set up (missing runtime or model)"""


def _softmax(logits):
	e = np.exp(logits - np.max(logits))
	return e / e.sum()


def crop_face(image, x, y, w, h, scale, size=INPUT_SIZE):
	"""Crop a square-ish region around the face, `scale` times the face box, and resize it"""
	src_h, src_w = image.shape[:2]
	if w <= 1 or h <= 1:
		return None

	scale = min((src_h - 1) / h, (src_w - 1) / w, scale)
	new_w, new_h = w * scale, h * scale
	cx, cy = x + w / 2, y + h / 2

	x1 = max(0, int(cx - new_w / 2))
	y1 = max(0, int(cy - new_h / 2))
	x2 = min(src_w - 1, int(cx + new_w / 2))
	y2 = min(src_h - 1, int(cy + new_h / 2))

	cropped = image[y1:y2 + 1, x1:x2 + 1]
	if cropped.size == 0:
		return None

	return cv2.resize(cropped, (size, size))


class Liveness:
	"""Scores how likely a face in a frame belongs to a live person"""

	def __init__(self):
		try:
			import onnxruntime as ort
		except ImportError as err:
			raise LivenessError("onnxruntime is not installed (pacman -S python-onnxruntime)") from err

		options = ort.SessionOptions()
		options.log_severity_level = 3

		self.models = []
		for name, (digest, scale) in MODELS.items():
			path = paths_factory.liveness_model_path(name)

			try:
				with open(path, "rb") as handle:
					data = handle.read()
			except OSError as err:
				raise LivenessError("cannot read liveness model " + path) from err

			# Load from the bytes we hashed, not from the path, so the file
			# cannot be swapped between the check and the load
			if hashlib.sha256(data).hexdigest() != digest:
				raise LivenessError("liveness model " + path + " does not match its expected hash")

			session = ort.InferenceSession(data, sess_options=options, providers=["CPUExecutionProvider"])
			self.models.append((session, session.get_inputs()[0].name, scale))

	def score(self, image, x, y, w, h):
		"""Probability (0-1) that the face at the given box is real.

		image must be a full-resolution BGR frame; x, y, w, h are in its pixels.
		Returns 0.0 when the box cannot be evaluated, so callers fail closed."""
		total = 0.0

		for session, input_name, scale in self.models:
			face = crop_face(image, x, y, w, h, scale)
			if face is None:
				return 0.0

			tensor = np.expand_dims(np.transpose(face.astype(np.float32), (2, 0, 1)), axis=0)
			logits = session.run(None, {input_name: tensor})[0][0]
			total += float(_softmax(logits)[REAL_CLASS])

		return total / len(self.models)
