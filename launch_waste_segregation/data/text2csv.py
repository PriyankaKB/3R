import csv

input_file = "mit_dataset.txt"
output_file = "mit_dataset.csv"

with open(input_file, "r", encoding="utf-8") as infile, open(output_file, "w", newline="", encoding="utf-8") as outfile:
    writer = csv.writer(outfile, quoting=csv.QUOTE_ALL)  # force double quotes
    writer.writerow(["sentence1", "sentence2", "label"])  # header
    
    for line in infile:
        line = line.strip()
        if not line:
            continue
        
        # Last token is the label (0/1)
        *text_parts, label = line.split()
        text = " ".join(text_parts)

        # Split sentences using ". " as delimiter
        sentences = text.split(". ")
        if len(sentences) >= 2:
            sentence1 = sentences[0].strip() + "."  # add back the period
            sentence2 = ". ".join(sentences[1:]).strip()
        else:
            sentence1 = text.strip()
            sentence2 = ""

        writer.writerow([sentence1, sentence2, label])
