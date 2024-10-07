import csv
import gzip

def detect_delimiter(file_path):
    with open(file_path, 'r') as file:
        sample = file.read(2048)  # Read a sample of the file
        sniffer = csv.Sniffer()
        delimiter = sniffer.sniff(sample).delimiter
        file.close()
    return delimiter

def detect_delimiter_compressed(file_path):
    with gzip.open(file_path, 'rt') as file:  # Open the .gz file in text mode
        sample = file.read(2048)  # Read a sample of the file
        sniffer = csv.Sniffer()
        delimiter = sniffer.sniff(sample).delimiter
    return delimiter


