#! /usr/bin/env bash

extract() {
  local label=$1
  local program=$2
  local extension=$3
  local path=$4

  if [ $(find . -maxdepth 1 -type f -name "*$extension" | wc -l) -gt 0 ]; then
    for f in *.$extension; do
      $program "$f"
      echo "Extracted with $label: $f"
      rm "$f"
    done
  else
    echo "No files to be extract with $label in $path"
  fi
}

arr=(
  "7 Zip|7z x|7z"
  "Unzip|unzip|zip"
  "Unrar|unrar x|rar"
)

for item in "${arr[@]}"; do
  IFS='|' read -r a b c <<< "$item"
  extract "$a" "$b" "$c" "$1"
done

echo "Done!"
