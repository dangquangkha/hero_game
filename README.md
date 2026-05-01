# Hướng dẫn dự án hero_game

Dưới đây là cấu trúc thư mục tự động cập nhật:

<!-- START_TREE -->
```text
your-game/
├── assets/
│   ├── audio/
│   │   ├── music/
│   │   │   ├── battle_01.ogg
│   │   │   ├── boss_theme.ogg
│   │   │   ├── menu_theme.ogg
│   │   │   └── victory.ogg
│   │   └── sfx/
│   │       ├── combat/
│   │       │   ├── explosion.wav
│   │       │   └── hit.wav
│   │       ├── player/
│   │       │   ├── attack.wav
│   │       │   ├── hurt.wav
│   │       │   └── jump.wav
│   │       └── ui/
│   │           ├── click.wav
│   │           └── hover.wav
│   ├── data/
│   │   ├── achievements/
│   │   │   └── achievements.json
│   │   ├── bullet_patterns/
│   │   │   ├── circle_burst.json
│   │   │   ├── custom_patterns.json
│   │   │   └── spiral.json
│   │   ├── cutscenes/
│   │   │   ├── boss_defeat.json
│   │   │   └── intro_cutscene.json
│   │   ├── dialogues/
│   │   │   ├── cutscenes/
│   │   │   │   ├── finale.json
│   │   │   │   └── intro.json
│   │   │   ├── boss_dialogues.json
│   │   │   └── npc_merchant.json
│   │   ├── enemies/
│   │   │   ├── bosses.json
│   │   │   └── common_enemies.json
│   │   ├── items/
│   │   │   ├── consumables.json
│   │   │   ├── equipment.json
│   │   │   └── weapons.json
│   │   ├── localization/
│   │   │   ├── en.json
│   │   │   └── vi.json
│   │   ├── maps/
│   │   │   ├── boss_arenas/
│   │   │   │   └── demon_king_arena.json
│   │   │   ├── dungeon_01.json
│   │   │   └── overworld.json
│   │   ├── scenarios/
│   │   │   ├── endings/
│   │   │   │   ├── bad_ending.json
│   │   │   │   └── true_ending.json
│   │   │   ├── chapter_01.json
│   │   │   └── prologue.json
│   │   └── skills/
│   │       ├── boss_skills.json
│   │       └── player_skills.json
│   ├── fonts/
│   │   ├── damage_numbers.ttf
│   │   ├── dialogue.ttf
│   │   └── main.ttf
│   ├── images/
│   │   ├── backgrounds/
│   │   │   ├── battle/
│   │   │   ├── cutscenes/
│   │   │   └── menu/
│   │   ├── characters/
│   │   │   ├── bosses/
│   │   │   ├── enemies/
│   │   │   ├── npcs/
│   │   │   └── player/
│   │   │       ├── attack.png
│   │   │       ├── idle.png
│   │   │       └── run.png
│   │   ├── effects/
│   │   │   ├── explosions/
│   │   │   ├── particles/
│   │   │   └── projectiles/
│   │   ├── items/
│   │   │   ├── consumables/
│   │   │   ├── equipment/
│   │   │   └── weapons/
│   │   ├── tilesets/
│   │   └── ui/
│   │       ├── buttons/
│   │       ├── fonts/
│   │       ├── icons/
│   │       └── panels/
│   └── shaders/
│       ├── blur.glsl
│       ├── chromatic.glsl
│       └── outline.glsl
├── docs/
│   ├── ai_prompts/
│   │   ├── boss_pattern_template.txt
│   │   └── entity_template.txt
│   ├── architecture.md
│   ├── coding_standards.md
│   ├── data_formats.md
│   └── entity_reference.md
├── libs/
│   ├── hump/
│   │   ├── camera.lua
│   │   ├── gamestate.lua
│   │   └── timer.lua
│   ├── middleclass/
│   │   ├── performance/
│   │   │   ├── run.lua
│   │   │   └── time.lua
│   │   ├── rockspecs/
│   │   │   ├── middleclass-3.0-0.rockspec
│   │   │   ├── middleclass-3.1-0.rockspec
│   │   │   ├── middleclass-3.2-0.rockspec
│   │   │   ├── middleclass-4.0-0.rockspec
│   │   │   ├── middleclass-4.1-0.rockspec
│   │   │   └── middleclass-4.1.1-0.rockspec
│   │   ├── spec/
│   │   │   ├── class_spec.lua
│   │   │   ├── classes_spec.lua
│   │   │   ├── default_methods_spec.lua
│   │   │   ├── instances_spec.lua
│   │   │   ├── metamethods_lua_5_2.lua
│   │   │   ├── metamethods_lua_5_3.lua
│   │   │   ├── metamethods_spec.lua
│   │   │   └── mixins_spec.lua
│   │   ├── CHANGELOG.md
│   │   ├── middleclass.lua
│   │   ├── MIT-LICENSE.txt
│   │   ├── README.md
│   │   └── UPDATING.md
│   ├── anim8.lua
│   ├── bump.lua
│   ├── flux.lua
│   ├── inspect.lua
│   ├── json.lua
│   ├── lume.lua
│   └── STI.lua
├── src/
│   ├── audio/
│   │   ├── AudioManager.lua
│   │   ├── AudioMixer.lua
│   │   ├── MusicPlayer.lua
│   │   └── SFXPlayer.lua
│   ├── core/
│   │   ├── camera.lua
│   │   ├── config.lua
│   │   ├── event.lua
│   │   ├── gamestate.lua
│   │   ├── input.lua
│   │   └── save.lua
│   ├── effects/
│   │   ├── ExplosionEffect.lua
│   │   ├── FlashEffect.lua
│   │   ├── ParticleManager.lua
│   │   ├── ScreenShake.lua
│   │   └── TrailRenderer.lua
│   ├── entities/
│   │   ├── base/
│   │   │   ├── Actor.lua
│   │   │   ├── Entity.lua
│   │   │   └── Projectile.lua
│   │   ├── bosses/
│   │   │   ├── types/
│   │   │   │   ├── DemonKing.lua
│   │   │   │   ├── DragonLord.lua
│   │   │   │   └── NecromancerQueen.lua
│   │   │   ├── Boss.lua
│   │   │   └── BossPhaseManager.lua
│   │   ├── enemies/
│   │   │   ├── types/
│   │   │   │   ├── FlyingEye.lua
│   │   │   │   ├── GoblinWarrior.lua
│   │   │   │   └── MageTower.lua
│   │   │   ├── Enemy.lua
│   │   │   └── EnemyTypes.lua
│   │   ├── npcs/
│   │   │   ├── types/
│   │   │   │   ├── Companion.lua
│   │   │   │   ├── Merchant.lua
│   │   │   │   └── QuestGiver.lua
│   │   │   └── NPC.lua
│   │   ├── player/
│   │   │   ├── Player.lua
│   │   │   ├── PlayerAbilities.lua
│   │   │   └── PlayerStates.lua
│   │   └── projectiles/
│   │       ├── Bullet.lua
│   │       ├── BulletPatterns.lua
│   │       ├── HomingBullet.lua
│   │       └── LaserBeam.lua
│   ├── screens/
│   │   ├── BattleScreen.lua
│   │   ├── CharacterSelect.lua
│   │   ├── GameOverScreen.lua
│   │   ├── InventoryScreen.lua
│   │   ├── MainMenu.lua
│   │   ├── MapScreen.lua
│   │   ├── PauseMenu.lua
│   │   ├── SettingsScreen.lua
│   │   ├── ShopScreen.lua
│   │   ├── SplashScreen.lua
│   │   ├── UpgradeScreen.lua
│   │   └── VictoryScreen.lua
│   ├── systems/
│   │   ├── achievement/
│   │   │   ├── AchievementData.lua
│   │   │   └── AchievementManager.lua
│   │   ├── combat/
│   │   │   ├── BulletManager.lua
│   │   │   ├── CombatManager.lua
│   │   │   ├── ComboTracker.lua
│   │   │   ├── DamageCalculator.lua
│   │   │   ├── SkillSystem.lua
│   │   │   └── StatusEffects.lua
│   │   ├── cutscene/
│   │   │   ├── CameraDirector.lua
│   │   │   ├── CutscenePlayer.lua
│   │   │   ├── SkipController.lua
│   │   │   └── Timeline.lua
│   │   ├── dialogue/
│   │   │   ├── CharacterPortrait.lua
│   │   │   ├── ChoiceMenu.lua
│   │   │   ├── DialogueBox.lua
│   │   │   ├── DialogueManager.lua
│   │   │   └── DialogueParser.lua
│   │   ├── inventory/
│   │   │   ├── items/
│   │   │   │   ├── consumables/
│   │   │   │   │   ├── Potion.lua
│   │   │   │   │   └── Scroll.lua
│   │   │   │   ├── equipment/
│   │   │   │   │   ├── Accessory.lua
│   │   │   │   │   └── Armor.lua
│   │   │   │   └── weapons/
│   │   │   │       ├── Bow.lua
│   │   │   │       ├── Staff.lua
│   │   │   │       └── Sword.lua
│   │   │   ├── Inventory.lua
│   │   │   ├── Item.lua
│   │   │   └── ItemDatabase.lua
│   │   ├── map/
│   │   │   ├── CollisionMap.lua
│   │   │   ├── MapManager.lua
│   │   │   ├── Minimap.lua
│   │   │   ├── TileMap.lua
│   │   │   └── TriggerZone.lua
│   │   ├── puzzle/
│   │   │   ├── types/
│   │   │   │   ├── PatternMatch.lua
│   │   │   │   ├── RiddleSolver.lua
│   │   │   │   └── SlidingBlock.lua
│   │   │   └── PuzzleManager.lua
│   │   ├── roguelike/
│   │   │   ├── DifficultyScaling.lua
│   │   │   ├── LootTable.lua
│   │   │   ├── MetaProgression.lua
│   │   │   ├── RoomGenerator.lua
│   │   │   └── RunManager.lua
│   │   ├── shop/
│   │   │   ├── Currency.lua
│   │   │   ├── ShopInventory.lua
│   │   │   └── ShopManager.lua
│   │   ├── story/
│   │   │   ├── BranchingTree.lua
│   │   │   ├── FlagSystem.lua
│   │   │   ├── ScenarioLoader.lua
│   │   │   └── StoryManager.lua
│   │   └── upgrade/
│   │       ├── AbilityUnlock.lua
│   │       ├── StatUpgrade.lua
│   │       └── UpgradeTree.lua
│   ├── ui/
│   │   ├── animations/
│   │   │   ├── NumberPopup.lua
│   │   │   └── UITransition.lua
│   │   ├── components/
│   │   │   ├── Button.lua
│   │   │   ├── Checkbox.lua
│   │   │   ├── Modal.lua
│   │   │   ├── Notification.lua
│   │   │   ├── Panel.lua
│   │   │   ├── ProgressBar.lua
│   │   │   ├── Slider.lua
│   │   │   └── Tooltip.lua
│   │   └── hud/
│   │       ├── BattleHUD.lua
│   │       ├── MinimapHUD.lua
│   │       └── QuestTracker.lua
│   └── utils/
│       ├── animation/
│       │   ├── Animator.lua
│       │   ├── StateMachine.lua
│       │   └── Tween.lua
│       ├── debug/
│       │   ├── Console.lua
│       │   ├── DebugDraw.lua
│       │   └── Profiler.lua
│       ├── helpers/
│       │   ├── Color.lua
│       │   ├── Pool.lua
│       │   ├── String.lua
│       │   ├── Table.lua
│       │   └── Timer.lua
│       └── math/
│           ├── Collision.lua
│           ├── Easing.lua
│           └── Vector2.lua
├── tools/
│   ├── build_scripts/
│   │   ├── build_linux.sh
│   │   ├── build_mac.sh
│   │   └── build_win.bat
│   ├── dialogue_editor/
│   └── map_editor/
├── conf.lua
├── main.lua
├── README.md
└── README_V1.md
```
<!-- END_TREE -->

Các ghi chú khác của dự án bạn có thể viết tiếp ở dưới này...