def compare_files():
    with open("mem_export_disc/tb_golden_disc.hex") as f1, open("mem_export_disc/inference_disc_out.hex") as f2:
        gold = [line.strip() for line in f1 if line.strip()]
        infer = [line.strip() for line in f2 if line.strip()]

    print(f"Golden Length: {len(gold)}")
    print(f"Infer  Length: {len(infer)}")

    if len(gold) == len(infer):
        print("\n--- Content Comparison ---")
        for i, (g, h) in enumerate(zip(gold, infer)):
            print(f"Pixel {i}: Gold={g} | Infer={h}")
    else:
        print("Mismatch! Please re-run disc_export.py to overwrite the old golden file.")

compare_files()