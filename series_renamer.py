#! /usr/bin/env python3

import os
import re
import shutil
import sys

class Title:
  @staticmethod
  def Regex(filename: str) -> str:
    match = re.search("([S|T]|Season)?\s*\d+x?\s*(E|Episode)?\s*\d+", item)
    if not match:
      raise Exception("No match!")

    extension = item.split(".")[-1]
    return f"{match.group(0).replace('T', 'S')}.{extension}"

  def __init__(self, og_filename: str, season: int = None, episode: int = None):
    self.__og_filename = og_filename
    self.__season = season or Title.__ExtractSeason(og_filename)
    first_n = self.__og_filename.split(" ")[0]
    if not episode and first_n.isdigit():
      self.__episode = int(first_n)
    else:
      self.__episode = episode or Title.__ExtractEpisode(og_filename)

  def get_og_filename(self) -> str:
    return self.__og_filename

  def get_filename(self) -> str:
    season_n = self.__append_zero(self.__season)
    episode_n = self.__append_zero(self.__episode)
    extension = self.__og_filename.split(".")[-1]
    return f"S{season_n}E{episode_n}.{extension}"

  def __append_zero(self, n: int) -> str:
    return f"0{n}" if n < 10 else str(n)

  @staticmethod
  def __ExtractEpisode(filename: str) -> int:
    match = Title.__ExtractNextToken(filename, ["episodio", "episódio", "episode", "ep"])
    return int(match) if match.isdigit() else 1

  @staticmethod
  def __ExtractSeason(filename: str) -> int:
    match = Title.__ExtractNextToken(filename, ["temporada", "season", "temp", "se"])
    return int(match) if match.isdigit() else 1

  @staticmethod
  def __ExtractNextToken(text: str, matchs: list[str]) -> str:
    text = text.lower()
    for match in matchs:
      if text.__contains__(match):
        index = text.find(match)
        return text[index + len(match):].strip().split(" ")[0].split(".")[0]

    return ""


if __name__ == "__main__":
  commands = ["move", "list", "regex-list", "regex-move"]
  if len(sys.argv) < 3:
    raise Exception(f"Invalid command, try {sys.argv[0]} {' | '.join(commands)} <path>")

  command = sys.argv[1]
  commands.index(command)
  path = sys.argv[2]
  season = int(sys.argv[3]) if len(sys.argv) >= 4 else None

  items = os.listdir(path)
  items.sort()
  for item in items:
    if not os.path.isdir(item) and (item.endswith(".mkv") or item.endswith(".mp4")):
      if command == "move":
        title = Title(item, season)
        shutil.move(f"{path}/{title.get_og_filename()}", f"{path}/{title.get_filename()}")
      elif command == "regex-move":
        shutil.move(f"{path}/{item}", f"{path}/{Title.Regex(item)}")
      elif command == "regex-list":
        print(Title.Regex(item))
      else:
        title = Title(item, season)
        print(title.get_og_filename())
        print(title.get_filename())
