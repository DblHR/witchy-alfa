extends Resource
class_name CharacterData

@export var id: String
@export var display_name: String
@export_enum("воин", "маг", "саппорт", "танк", "рядовой враг", "босс") var unit_class: String = "маг"
@export var tags: Array[String] = []

## Главный герой (Ведьмочка, Воин): у него нет отношений и повторок — игрок играет за него.
@export var is_protagonist: bool = false

## Ранг героя: A — до 4 карт в бой и простая механика, S — до 8 карт и более сложная.
@export_enum("A", "S") var rank: String = "A"
const RANK_CARD_CAP := {"A": 4, "S": 8}

func card_cap() -> int:
	return int(RANK_CARD_CAP.get(rank, 4))

# Для UI/иконок/спрайтов (пока можно оставить пустым)
@export var icon: Texture2D
@export var battle_texture: Texture2D

# --- Характеристики карточного боя (на 1 уровне) ---
## Максимальное HP.
@export var base_hp: int = 10
## Сила атаки: скейлит урон карт (значение = база + доля × Атака).
@export var attack: int = 5
## Сила магии: скейлит щиты, лечение и прочие числа карт поддержки.
@export var magic: int = 5
## Энергия ульты: сколько карт героя нужно сыграть, чтобы ульта зарядилась.
@export var max_energy: int = 5

# Рост за уровень — общий для всех: +10% от базы (CardBalance.GROWTH_PER_LEVEL).
# Поля ниже остались от старой линейной прокачки и больше не используются.
@export var hp_per_level: int = 1
@export var attack_per_level: int = 0
@export var magic_per_level: int = 0

# --- Карты ---
## Портрет, выезжающий слева, пока тащишь карту героини (как в CZN). Пусто — ищется
## res://assets/characters/<id>/<id>_drag.png. Прозрачные поля обрезаются сами.
@export var drag_portrait: Texture2D
## Заставка ульты (по центру экрана при активации). Пусто — ищется файл в
## assets/characters/<id>/, имя которого начинается с id и содержит «ult» (fufu_ult.png).
@export var ult_splash: Texture2D
## Цвет карт героя.
@export var card_color: Color = Color(0.45, 0.45, 0.50, 1.0)
## Стартовые карты героя: есть сразу, идут в колоду (не больше card_cap() по рангу).
@export var card_pool: Array[CardDef] = []
## Карты, которые открываются позже (за отношения). Пока не открыты — в инвентаре «не получена».
## Открываются по уровню доверия (UnitRoster_.get_relationship).
@export var unlock_cards: Array[CardDef] = []
## Ульта (не карта колоды: копит заряд и жмётся кнопкой).
@export var ult_card: CardDef
## Пассивка в карточном бою (необязательно).
@export var card_passive: CardPassive

# --- Наследие автобаттлера (в карточном бою не используется) ---
@export var base_damage: int = 1
@export var base_aps: float = 1.0
@export var damage_per_level: int = 0
@export var aps_per_level: float = 0.0

@export var battle_scale: float = 0.25
@export var battle_offset_y: float = -500

@export var card_portrait: Texture2D
@export var skill_icon: Texture2D

@export var skill_cost: int = 3
@export var skill_name: String = "Умение"
@export_multiline var codex_description: String = ""
@export_multiline var codex_notes: String = ""

# Data-driven abilities (альфа): если заданы, BattleSim/PlayerCard будут использовать их.
@export var skill_ability: Ability
@export var ult_ability: Ability

# Считает статы для героя/компаньона по уровню
func stats_for_level(level: int) -> Dictionary:
	var lvl: int = maxi(level, 1)
	return {
		"max_hp": roundi(float(CardBalance.scale_by_level(base_hp, lvl)) * CardBalance.hero_hp_mult),
		"attack": CardBalance.scale_by_level(attack, lvl),
		"magic": CardBalance.scale_by_level(magic, lvl),
		"damage": int(base_damage + damage_per_level * (lvl - 1)),
		"aps": float(base_aps + aps_per_level * (lvl - 1)),
	}
