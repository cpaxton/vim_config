#!/usr/bin/env bash
#
## HoNY RGB + actions dataset, 814 MB
wget https://dl.dobb-e.com/datasets/homes_of_new_york.zip
unzip homes_of_new_york.zip

# HoNY RGB-D + actions dataset, 77 GB
pip install gdown
python -c "import gdown; gdown.download_folder('https://drive.google.com/drive/folders/1o8c6b6hSKfId8EzemVGf8c7DQoZ2IHAO?usp=sharing', quiet=True)"
zip -FF HomesOfNewYorkWithDepth.zip --out HoNYDepth.zip
unzip -FF HoNYDepth.zip

# Sample finetuning dataset
wget https://dl.dobb-e.com/datasets/finetune_directory.zip
unzip finetune_directory.zip

