#!/usr/bin/env python3
"""Convert an open_clip model to ONNX encoders that dimoose runs without torch.

Run this once, in a Python that has torch and open_clip (the packages in
requirements.txt) plus those in requirements-export.txt:

    python export_onnx.py --model ViT-B-32 --pretrained openai --out clip-vit-b-32
    python export_onnx.py --model hf-hub:imageomics/bioclip --out bioclip --quantize int8 fp16

It writes into the --out folder:

    dimoose_onnx.json        what is in the folder: architecture, image size,
                             preprocessing constants, file names and sizes
    image_encoder.onnx       pixel_values [n,3,S,S] float32 ->
                               image_embeds [n,d]        (not normalised)
                               patch_embeds [n,g*g,d]    (projected patch tokens)
    text_encoder.onnx        input_ids [n,77] int64 -> text_embeds [n,d]
    tokenizer.json           the model's tokenizer, in the Hugging Face
                             `tokenizers` format (also read by transformers.js)
    image_encoder_int8.onnx, text_encoder_int8.onnx    with --quantize int8
    image_encoder_fp16.onnx, text_encoder_fp16.onnx    with --quantize fp16

The folder is then used with dimoose_onnx.load_model(folder), which needs only
onnxruntime, numpy, pillow and tokenizers. In R: onnxModel(folder), or visionModel(name = folder, backend = "onnx").

Each exported file is checked against the torch model on random input and the
cosine similarity of the embeddings is printed with the file sizes.
"""
import argparse
import json
import os
import sys
import warnings

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

CONFIG = "dimoose_onnx.json"
SUFFIX = {"fp32": "", "fp16": "_fp16", "int8": "_int8"}


def build_tokenizer(tok):
    """open_clip's SimpleTokenizer as a `tokenizers` Tokenizer.

    The result gives the same token ids, start and end tokens included; the
    caller pads or cuts them to the context length (see dimoose_onnx.tokenize).
    """
    from tokenizers import Regex, Tokenizer, decoders, models, normalizers, pre_tokenizers, processors
    if not all(hasattr(tok, a) for a in ("encoder", "bpe_ranks", "sot_token_id", "eot_token_id")):
        raise ValueError("only models that use open_clip's own CLIP tokenizer can be exported; this one uses %s"
                         % type(tok).__name__)
    merges = [pair for pair, _ in sorted(tok.bpe_ranks.items(), key=lambda kv: kv[1])]
    names = {i: t for t, i in tok.encoder.items()}
    sot, eot = names[tok.sot_token_id], names[tok.eot_token_id]
    t = Tokenizer(models.BPE(vocab=dict(tok.encoder), merges=merges, end_of_word_suffix="</w>",
                             continuing_subword_prefix="", unk_token=eot))
    t.normalizer = normalizers.Sequence([normalizers.NFC(), normalizers.Replace(Regex(r"\s+"), " "),
                                         normalizers.Strip(), normalizers.Lowercase()])
    t.pre_tokenizer = pre_tokenizers.Sequence([
        pre_tokenizers.Split(Regex(r"'s|'t|'re|'ve|'m|'ll|'d|[\p{L}]+|[\p{N}]|[^\s\p{L}\p{N}]+"),
                             behavior="removed", invert=True),
        pre_tokenizers.ByteLevel(add_prefix_space=False, use_regex=False)])
    t.post_processor = processors.TemplateProcessing(
        single=sot + " $A " + eot, special_tokens=[(sot, tok.sot_token_id), (eot, tok.eot_token_id)])
    t.decoder = decoders.ByteLevel()
    t.add_special_tokens([sot, eot])
    return t


CHECK_TEXTS = ["a photo of Acer negundo.", "A  photo of a Quaking aspen (Populus tremuloides)!",
               "it's the 3rd leaf's lobe, isn't it?", "Bläuling & café: 12 petals", "x " * 200]


def check_tokenizer(tok, t, context_length):
    """Fail unless the converted tokenizer gives open_clip's token ids."""
    import dimoose_onnx
    want = tok(CHECK_TEXTS).numpy()
    got = dimoose_onnx.tokenize(t, CHECK_TEXTS, context_length, eot_id=tok.eot_token_id, pad_id=0)
    if not np.array_equal(want, got):
        bad = [s for s, a, b in zip(CHECK_TEXTS, want, got) if not np.array_equal(a, b)]
        raise ValueError("the converted tokenizer does not reproduce open_clip's token ids for: %r" % bad)


def export(module, example, path, input_name, output_names, opset):
    """Write `module` to `path` with a free batch size."""
    import torch
    axes = {n: {0: "batch"} for n in [input_name] + output_names}
    # nn.MultiheadAttention has a fused fast path for inference that the
    # exporter cannot translate; without it the attention is exported as
    # ordinary matrix products with the same result.
    mha = getattr(torch.backends, "mha", None)
    fast = mha.get_fastpath_enabled() if mha is not None else None
    if mha is not None:
        mha.set_fastpath_enabled(False)
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            try:
                torch.onnx.export(module, (example,), path, input_names=[input_name], output_names=output_names,
                                  dynamic_axes=axes, opset_version=opset, dynamo=False)
            except TypeError:   # a torch without the `dynamo` argument
                torch.onnx.export(module, (example,), path, input_names=[input_name], output_names=output_names,
                                  dynamic_axes=axes, opset_version=opset)
    finally:
        if mha is not None:
            mha.set_fastpath_enabled(fast)


def to_fp16(src, dst):
    """Weights as 16-bit floats; inputs and outputs stay float32."""
    import onnx
    try:
        from onnxconverter_common.float16 import convert_float_to_float16
    except ImportError:
        from onnxruntime.transformers.float16 import convert_float_to_float16
    model = onnx.load(src)
    # Casts to float32 inside the graph (open_clip's LayerNorm casts back to
    # its input's type) must follow the weights to 16 bits; the converter
    # leaves them alone and the file would not load.
    casts = {n.name for n in model.graph.node if n.op_type == "Cast"
             and any(a.name == "to" and a.i == onnx.TensorProto.FLOAT for a in n.attribute)}
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        model = convert_float_to_float16(model, keep_io_types=True)
    for n in model.graph.node:
        if n.name in casts:
            for a in n.attribute:
                if a.name == "to":
                    a.i = onnx.TensorProto.FLOAT16
    onnx.save(model, dst)


def to_int8(src, dst, min_size=1024):
    """Weights as 8-bit integers, arithmetic in float.

    Each large weight matrix is stored as int8 with one scale per output
    channel, followed by a DequantizeLinear node that turns it back into
    floats when the model is loaded. The file is a quarter of the size and
    everything after loading is the float model's arithmetic, so every
    runtime gives the same embeddings.

    onnxruntime's own "dynamic quantisation" (quantize_dynamic), which also
    does the matrix products in integers, was measured and set aside: with
    BioCLIP's image encoder on dimoose's example photos its embeddings had a
    cosine of 0.995 with the float model's under onnxruntime on a desktop
    CPU, but only 0.90 to 0.96 under onnxruntime-web's WebAssembly backend,
    whose integer products differ. Integer weights alone give 0.998 in both.

    The convolution that cuts the image into patches stays in float (7 MB or
    less): its few weights matter more than any others.
    """
    import onnx
    from onnx import TensorProto, helper, numpy_helper
    model = onnx.load(src)
    opset = max([o.version for o in model.opset_import if o.domain in ("", "ai.onnx")] or [0])
    if opset < 13:
        raise ValueError("int8 weights need ONNX opset 13 or later (DequantizeLinear with a scale per channel); this file has %d" % opset)
    graph = model.graph
    users = {}
    for node in graph.node:
        for name in node.input:
            users.setdefault(name, set()).add(node.op_type)
    tensors, nodes = [], []
    for init in list(graph.initializer):
        ops = users.get(init.name, set())
        if (init.data_type != TensorProto.FLOAT or len(init.dims) < 2 or int(np.prod(init.dims)) < min_size
                or not ops or "Conv" in ops):
            continue
        w = numpy_helper.to_array(init)
        # the channel is the output unit of a matrix product (the last axis of
        # the second factor, the first of Gemm's weight) and the row of a
        # table that is looked up (Gather: one scale per token)
        axis = 0 if ops & {"Gemm", "Gather"} else w.ndim - 1
        largest = np.abs(w).max(axis=tuple(i for i in range(w.ndim) if i != axis))
        scale = np.where(largest > 0, largest / 127.0, 1.0).astype(np.float32)
        shape = [-1 if i == axis else 1 for i in range(w.ndim)]
        q = np.clip(np.rint(w / scale.reshape(shape)), -127, 127).astype(np.int8)
        names = [init.name + "_int8", init.name + "_scale", init.name + "_zero"]
        tensors += [numpy_helper.from_array(q, names[0]), numpy_helper.from_array(scale, names[1]),
                    numpy_helper.from_array(np.zeros(scale.shape, dtype=np.int8), names[2])]
        nodes.append(helper.make_node("DequantizeLinear", names, [init.name], name=init.name + "_dequantize", axis=axis))
        graph.initializer.remove(init)
    if not nodes:
        raise ValueError("found no weight matrices to store as int8 in %s" % src)
    graph.initializer.extend(tensors)
    rest = list(graph.node)
    del graph.node[:]
    graph.node.extend(nodes + rest)
    onnx.save(model, dst)


def cosines(a, b):
    a = a / np.linalg.norm(a, axis=-1, keepdims=True)
    b = b / np.linalg.norm(b, axis=-1, keepdims=True)
    return (a * b).sum(-1)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--model", default="ViT-B-32",
                    help='open_clip architecture, "hf-hub:<org>/<model>" or "local-dir:<folder>"')
    ap.add_argument("--pretrained", default="openai", help="open_clip's tag for the weights of an architecture")
    ap.add_argument("--weights", default=None, help="local checkpoint file instead of a download")
    ap.add_argument("--out", required=True, help="folder to write to")
    ap.add_argument("--quantize", nargs="*", default=[], choices=["int8", "fp16"],
                    help="also write smaller copies of the encoders")
    ap.add_argument("--no-text", action="store_true", help="export the image encoder only")
    ap.add_argument("--opset", type=int, default=17)
    args = ap.parse_args(argv)

    import torch
    import onnxruntime as ort
    import dimoose_vision as mv

    os.makedirs(args.out, exist_ok=True)
    vm = mv.load_model(name=args.model, pretrained=args.pretrained, weights=args.weights)
    model, spec = vm.model, vm.spec
    visual = model.visual
    context_length = int(getattr(model, "context_length", 77))

    class ImageEncoder(torch.nn.Module):
        def __init__(self):
            super().__init__()
            self.visual = visual

        def forward(self, pixel_values):
            pooled, tokens = self.visual(pixel_values)
            if self.visual.proj is not None:
                tokens = tokens @ self.visual.proj
            return pooled, tokens

    class TextEncoder(torch.nn.Module):
        def __init__(self):
            super().__init__()
            self.model = model

        def forward(self, input_ids):
            return self.model.encode_text(input_ids)

    size = spec["image_size"]
    torch.manual_seed(0)
    pixels = torch.randn(2, 3, size, size)
    files = {"image_encoder": {}, "text_encoder": {}}
    report = []

    def variants(stem, module, example, input_name, output_names, reference):
        base = os.path.join(args.out, stem + ".onnx")
        export(module, example, base, input_name, output_names, args.opset)
        made = {"fp32": base}
        for q in args.quantize:
            dst = os.path.join(args.out, stem + SUFFIX[q] + ".onnx")
            (to_fp16 if q == "fp16" else to_int8)(base, dst)
            made[q] = dst
        for precision, path in made.items():
            sess = ort.InferenceSession(path, providers=["CPUExecutionProvider"])
            out = sess.run([output_names[0]], {input_name: example.numpy()})[0]
            cos = float(cosines(out, reference).min())
            files[stem][precision] = {"file": os.path.basename(path), "bytes": os.path.getsize(path)}
            report.append((os.path.basename(path), os.path.getsize(path), cos))

    with torch.no_grad():
        ref_image = visual(pixels)[0].numpy()
        variants("image_encoder", ImageEncoder().eval(), pixels, "pixel_values", ["image_embeds", "patch_embeds"], ref_image)
        tokenizer_file = None
        if not args.no_text:
            t = build_tokenizer(vm.tokenizer)
            check_tokenizer(vm.tokenizer, t, context_length)
            t.save(os.path.join(args.out, "tokenizer.json"))
            tokenizer_file = "tokenizer.json"
            ids = vm.tokenizer(CHECK_TEXTS[:2])
            ref_text = model.encode_text(ids).numpy()
            variants("text_encoder", TextEncoder().eval(), ids, "input_ids", ["text_embeds"], ref_text)

    norm = [t for t in vm.preprocess.transforms if hasattr(t, "mean") and hasattr(t, "std")]
    resize = [t for t in vm.preprocess.transforms if hasattr(t, "interpolation")]
    interpolation = str(getattr(resize[0], "interpolation", "bicubic")).split(".")[-1].lower() if resize else "bicubic"
    config = {
        "format": "dimoose-onnx",
        "version": 1,
        "arch": spec["arch"],
        "pretrained": spec["pretrained"],
        "weights_sha256": spec["weights_sha256"],
        "exported_from": spec["library"] + ", torch " + torch.__version__,
        "image_size": spec["image_size"],
        "patch_size": spec["patch_size"],
        "patch_grid": spec["patch_grid"],
        "dim": spec["dim"],
        "context_length": context_length,
        "logit_scale": float(model.logit_scale.detach().exp()) if hasattr(model, "logit_scale") else 100.0,
        "preprocess": {
            "resize": "shortest", "interpolation": interpolation, "crop": "center", "rescale": 1 / 255,
            "mean": [float(v) for v in norm[0].mean], "std": [float(v) for v in norm[0].std],
        },
        "image_encoder": files["image_encoder"],
        "text_encoder": files["text_encoder"],
        "inputs": {"image": "pixel_values", "text": "input_ids"},
        "outputs": {"image": "image_embeds", "patches": "patch_embeds", "text": "text_embeds"},
        "tokenizer": tokenizer_file,
        "sot_id": int(vm.tokenizer.sot_token_id) if tokenizer_file else None,
        "eot_id": int(vm.tokenizer.eot_token_id) if tokenizer_file else None,
        "pad_id": 0,
    }
    with open(os.path.join(args.out, CONFIG), "w") as f:
        json.dump(config, f, indent=2)

    print("%-28s %10s  %s" % ("file", "MB", "cosine with torch (random input, lowest)"))
    for name, size_bytes, cos in report:
        print("%-28s %10.1f  %.5f" % (name, size_bytes / 1e6, cos))
    print("wrote " + os.path.abspath(args.out))
    return config


if __name__ == "__main__":
    main()
