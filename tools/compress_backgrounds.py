#!/usr/bin/env python3
"""Опционально: переключает крупные ОПАКОВЫЕ фоны на VRAM-сжатие (Compress Mode = VRAM Compressed).

Что делает: в .import-файлах фонов из assets/pics/bigPics/backgrounds и endscreen меняет
compress/mode=0 (Lossless) на compress/mode=2 (VRAM Compressed). Видеопамять на каждый
фон 1920x1080 падает с ~8 МБ до ~2 МБ, на диске импортированный кэш тоже легче.
Исходные PNG не трогаются. Откат: запустить с флагом --undo.

Запускать из корня проекта при ЗАКРЫТОМ редакторе Godot, потом открыть проект (пойдёт реимпорт).
ЦЕНА: в памяти видеокарты выигрыш ~4x, но импортированный кэш и экспортный PCK на диске
вырастают (в тесте .godot/imported 26 МБ -> 41 МБ), т.к. хранятся сжатые варианты под разные GPU.
Это про загрузку и память, не про вес архива. Если важен вес сборки, смотрите режим Lossy (compress/mode=1).
Не применять к спрайтам с прозрачностью и к курсору (CursorFx читает пиксели текстуры).
"""
import sys, re, pathlib
undo = "--undo" in sys.argv
src, dst = ("2", "0") if undo else ("0", "2")
folders = ["assets/pics/bigPics/backgrounds", "assets/pics/bigPics/endscreen"]
changed = 0
for folder in folders:
    for p in pathlib.Path(folder).glob("*.png.import"):
        t = p.read_text(encoding="utf-8")
        n = re.sub(r"^compress/mode=%s$" % src, "compress/mode=%s" % dst, t, flags=re.M)
        if n != t:
            p.write_text(n, encoding="utf-8")
            changed += 1
print(("Откат: " if undo else "Готово: ") + "изменено файлов: %d" % changed)
