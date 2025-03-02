#! /usr/bin/env python3

import os
import shutil
import sys

COVER_EXTENSIONS = ["jpg", "jpeg", "png"]
IGNORE_ENTRIES = ["IGR_BG.TM2", "IGR_NO.TM2", "IGR_YES.TM2", "POPS_IOX.PAK", "POPSTARTER", "POPSTARTER.ELF"]
POPSTARTER_ELF = "POPSTARTER.ELF"

INTERNET_ARCHIVE_ART_PATH = "https://ia600701.us.archive.org/view_archive.php?archive=/11/items/OPLM_ART_2024_09/OPLM_ART_2024_09.zip&file=PS1%2F"

class Game:
  def __init__(self, path: str):
    self.__path = path

  def id(self) -> str:
    return ".".join(self.__path.split(".")[:2])

  def name(self) -> str:
    return self.__path.split(".")[2]

  def fullname(self) -> str:
    return ".".join(self.__path.split(".")[:3])

  def elfname(self) -> str:
    return f"XX.{self.fullname()}.ELF"

  def has_elf(self, pops_path: str) -> bool:
    elf_path = f"{pops_path}/{self.elfname()}"
    return os.path.isfile(elf_path)

  def has_art(self, art_path: str) -> bool:
    cover_path_without_ext = f"{art_path}/{self.elfname()}_COV"
    for extension in COVER_EXTENSIONS:
      if os.path.isfile(f"{cover_path_without_ext}.{extension}"):
        return True


    return False


if __name__ == "__main__":
  path = sys.argv[1]
  if not path:
    raise Exception("Invalid path")

  pops_path = f"{path}/POPS"
  if not os.path.isdir(pops_path):
    raise Exception(f"Invalid POPS path: {pops_path}")


  art_path = f"{path}/ART"
  if not os.path.isdir(art_path):
    raise Exception(f"Invalid ART path: {art_path}")


  conf_apps_path = f"{path}/conf_apps.cfg"
  if not os.path.isfile(conf_apps_path):
    raise Exception(f"Invalid conf apps file: {conf_apps_path}")


  popstarter_elf_path = f"{pops_path}/{POPSTARTER_ELF}"
  if not os.path.isfile(popstarter_elf_path):
    raise Exception(f"`{POPSTARTER_ELF}` not found in path: {pops_path}")


  with open(conf_apps_path, "r") as conf_apps_file:
    conf_apps_file_content = conf_apps_file.read()
    games_in_conf_apps = [line.split("=")[0] for line in conf_apps_file_content.split("\n")]


  for entry in os.listdir(pops_path):
    if entry not in IGNORE_ENTRIES and not entry.startswith("XX") and entry.endswith("VCD"):
      game = Game(path=entry)
      print(game.id())
      print(game.name())
      if not game.has_elf(pops_path):
        shutil.copyfile(popstarter_elf_path, f"{pops_path}/{game.elfname()}")


      if not game.has_art(art_path):
        import urllib.request
        file_types = ["COV", "BG_00", "LGO"]
        for file_type in file_types:
          filename = f"{game.id()}%2F{game.id()}_{file_type}.png"
          destination_filename = f"{game.elfname()}_{file_type.split("_")[0]}.png"
          try:
            urllib.request.urlretrieve(f"{INTERNET_ARCHIVE_ART_PATH}{filename}", f"{art_path}/{destination_filename}")
            print(f"Downloaded {file_type} for: {game.name()}")
          except:
            print(f"Failed to download {file_type} for: {game.name()}")


      if not game.name() in games_in_conf_apps:
        game_line = f"{game.name()}=mass0:/POPS/{game.elfname()}"
        with open(conf_apps_path, "a") as conf_apps_file:
          conf_apps_file.write(f"{game_line}\n")


      print("======")

