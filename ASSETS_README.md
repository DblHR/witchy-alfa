# Где лежат картинки (assets/)

```
assets/
  characters/<id>/            всё о героине: witch, warrior, aki, luisa, fufu
    <id>_portrait.png         портрет (Setup, диалоги, кружок ульты) — CharacterData.card_portrait
    <id>_battle.png           спрайт в бою и в доме — CharacterData.battle_texture
    <id>_drag.png             портрет, выезжающий слева при перетаскивании карты
    <id>_ult.png              заставка ульты (любой файл «<id>…ult…» в этой папке)
    <id>_spell_icon.png       значок умения
    cards/                    рисунки карт: <id карты>.png, <id>_atk.png / <id>_sup.png (общий арт по виду),
                              <id>.png (фон карт героини)
    love/                     картинки-сцены (CG) для диалогов: "cg": "res://assets/characters/fufu/love/fufu_hug.png"
    emotions/                 эмоции для диалогов: <id>_<эмоция>.png → "emotion": "<эмоция>" (fufu_shy.png → "shy")
  npc/                        rikka, sessilia, noctris (+ noctris_heal/revival/potion — картинки услуг), chest, statues
  enemies/slimes/             спрайты слизней
  cards/general/              рисунки общих карт (приманка); новые общие карты — assets/cards/common/<id>.png
  backgrounds/
    floor1/                   фон этажа слоями: sky, clouds, ground (FloorBackdrop.FLOORS)
    rooms/                    дом, лавки, медсестра, ферма, алхимия, инвентарь
    menu/                     главное меню и экран перед ним
  story/                      prologue/ (scene1…scene12), endscreen/ (victory, defeat)
  items/                      staffs/, food/, potions/, ingredients/, loot/, gift.png
  farm/                       pots/, plants/, seeds/, furniture/
  alchemy/                    котёл
  ui/                         buttons/, status/ (значки статусов и меч/щиток карт), cursor/ (курсор, частицы клика),
                              setup/, inventory/, menu/, battle/
  _unused/                    готовое, но пока не используется
```

## Правила
- Новую картинку кладите в папку по смыслу; имя — латиницей, без пробелов, через «_».
- Переносить уже подключённые картинки в проводнике нельзя: в скриптах и json пути записаны строками.
  Переносите внутри Godot (перетаскиванием в панели «Файловая система») — он сам обновит сцены и ресурсы,
  а пути в .gd / .json потом поищите поиском по проекту (Ctrl+Shift+F), или попросите Клодю.
- Новая героиня: папка assets/characters/<id>/ с теми же именами файлов — портрет при перетаскивании,
  заставка ульты и рисунки карт подхватятся сами.
