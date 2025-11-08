import onnx

model = onnx.load("best.onnx")

for node in model.graph.output:
    print(node.name)

print("Number of outputs:", len(model.graph.output))
