your-game/
├── main.lua                          # Entry point
├── conf.lua                          # LÖVE configuration
├── README.md                         # Hướng dẫn dự án
│
├── src/
│   │
│   ├── core/                         # ═══ HỆ THỐNG NỀN TẢNG ═══
│   │   ├── gamestate.lua             # Scene manager (menu/battle/cutscene/shop)
│   │   ├── input.lua                 # Input handler (keyboard/gamepad)
│   │   ├── camera.lua                # Camera với shake/zoom/follow
│   │   ├── event.lua                 # Event system (pub/sub pattern)
│   │   ├── save.lua                  # Save/Load system
│   │   └── config.lua                # Game settings (volume, resolution, keybinds)
│   │
│   ├── entities/                     # ═══ GAME OBJECTS ═══
│   │   ├── base/
│   │   │   ├── Entity.lua            # Base class cho mọi object
│   │   │   ├── Actor.lua             # Entities có HP/stats (Player, Enemies, Bosses)
│   │   │   └── Projectile.lua        # Base cho bullets/projectiles
│   │   │
│   │   ├── player/
│   │   │   ├── Player.lua            # Player character
│   │   │   ├── PlayerStates.lua      # State machine (idle/move/dash/hurt)
│   │   │   └── PlayerAbilities.lua   # Kỹ năng/special moves
│   │   │
│   │   ├── enemies/
│   │   │   ├── Enemy.lua             # Base enemy class
│   │   │   ├── EnemyTypes.lua        # Registry các loại enemy
│   │   │   │
│   │   │   └── types/                # Từng loại enemy cụ thể
│   │   │       ├── GoblinWarrior.lua
│   │   │       ├── MageTower.lua
│   │   │       └── FlyingEye.lua
│   │   │
│   │   ├── bosses/
│   │   │   ├── Boss.lua              # Base boss class
│   │   │   ├── BossPhaseManager.lua  # Quản lý phases (phase 1, 2, 3...)
│   │   │   │
│   │   │   └── types/                # Boss cụ thể
│   │   │       ├── DemonKing.lua
│   │   │       ├── DragonLord.lua
│   │   │       └── NecromancerQueen.lua
│   │   │
│   │   ├── projectiles/
│   │   │   ├── Bullet.lua            # Đạn cơ bản
│   │   │   ├── HomingBullet.lua      # Đạn tự tìm mục tiêu
│   │   │   ├── LaserBeam.lua         # Laser
│   │   │   └── BulletPatterns.lua    # Danmaku patterns (spiral, circle, wave)
│   │   │
│   │   └── npcs/
│   │       ├── NPC.lua               # Base NPC class
│   │       └── types/
│   │           ├── Merchant.lua
│   │           ├── QuestGiver.lua
│   │           └── Companion.lua
│   │
│   ├── systems/                      # ═══ GAME SYSTEMS ═══
│   │   │
│   │   ├── combat/
│   │   │   ├── CombatManager.lua     # Quản lý battle flow
│   │   │   ├── DamageCalculator.lua  # Tính damage, crit, elemental
│   │   │   ├── BulletManager.lua     # Pool bullets, collision
│   │   │   ├── SkillSystem.lua       # Hệ thống kỹ năng
│   │   │   ├── ComboTracker.lua      # Theo dõi combo chains
│   │   │   └── StatusEffects.lua     # Poison, burn, freeze, stun
│   │   │
│   │   ├── inventory/
│   │   │   ├── Inventory.lua         # Player inventory
│   │   │   ├── Item.lua              # Base item class
│   │   │   ├── ItemDatabase.lua      # Registry mọi items
│   │   │   │
│   │   │   └── items/                # Các loại item
│   │   │       ├── weapons/
│   │   │       │   ├── Sword.lua
│   │   │       │   ├── Bow.lua
│   │   │       │   └── Staff.lua
│   │   │       ├── consumables/
│   │   │       │   ├── Potion.lua
│   │   │       │   └── Scroll.lua
│   │   │       └── equipment/
│   │   │           ├── Armor.lua
│   │   │           └── Accessory.lua
│   │   │
│   │   ├── dialogue/
│   │   │   ├── DialogueManager.lua   # Quản lý conversations
│   │   │   ├── DialogueBox.lua       # UI hiển thị text
│   │   │   ├── DialogueParser.lua    # Parse script files
│   │   │   ├── ChoiceMenu.lua        # Branching choices
│   │   │   └── CharacterPortrait.lua # Character sprites
│   │   │
│   │   ├── story/
│   │   │   ├── StoryManager.lua      # Quản lý plot progression
│   │   │   ├── ScenarioLoader.lua    # Load scenario data
│   │   │   ├── FlagSystem.lua        # Story flags (bossDead, questComplete)
│   │   │   └── BranchingTree.lua     # Multiple story routes
│   │   │
│   │   ├── cutscene/
│   │   │   ├── CutscenePlayer.lua    # Chạy cutscenes
│   │   │   ├── Timeline.lua          # Timeline editor data
│   │   │   ├── CameraDirector.lua    # Camera movement in cutscenes
│   │   │   └── SkipController.lua    # Skip/pause cutscenes
│   │   │
│   │   ├── map/
│   │   │   ├── MapManager.lua        # Load/unload maps
│   │   │   ├── TileMap.lua           # Tile-based map rendering
│   │   │   ├── CollisionMap.lua      # Collision layer
│   │   │   ├── TriggerZone.lua       # Event triggers (enter area → cutscene)
│   │   │   └── Minimap.lua           # Minimap UI
│   │   │
│   │   ├── puzzle/
│   │   │   ├── PuzzleManager.lua     # Puzzle logic
│   │   │   └── types/
│   │   │       ├── SlidingBlock.lua
│   │   │       ├── PatternMatch.lua
│   │   │       └── RiddleSolver.lua
│   │   │
│   │   ├── roguelike/
│   │   │   ├── RunManager.lua        # Quản lý 1 run (reset khi chết)
│   │   │   ├── RoomGenerator.lua     # Procedural room gen
│   │   │   ├── LootTable.lua         # Random loot
│   │   │   ├── MetaProgression.lua   # Unlock permanent upgrades
│   │   │   └── DifficultyScaling.lua # Tăng độ khó theo floor
│   │   │
│   │   ├── upgrade/
│   │   │   ├── UpgradeTree.lua       # Skill tree
│   │   │   ├── StatUpgrade.lua       # HP, ATK, SPD upgrades
│   │   │   └── AbilityUnlock.lua     # Unlock new abilities
│   │   │
│   │   ├── shop/
│   │   │   ├── ShopManager.lua       # Mua/bán items
│   │   │   ├── ShopInventory.lua     # Shop stock
│   │   │   └── Currency.lua          # Gold, gems, tokens
│   │   │
│   │   └── achievement/
│   │       ├── AchievementManager.lua
│   │       └── AchievementData.lua
│   │
│   ├── screens/                      # ═══ GAME SCREENS ═══
│   │   ├── SplashScreen.lua          # Logo startup
│   │   ├── MainMenu.lua              # Main menu
│   │   ├── CharacterSelect.lua       # Chọn character
│   │   ├── BattleScreen.lua          # Màn chiến đấu chính
│   │   ├── MapScreen.lua             # Overworld map
│   │   ├── ShopScreen.lua            # Shop UI
│   │   ├── InventoryScreen.lua       # Inventory UI
│   │   ├── UpgradeScreen.lua         # Skill tree UI
│   │   ├── PauseMenu.lua             # Pause menu
│   │   ├── GameOverScreen.lua        # Game over
│   │   ├── VictoryScreen.lua         # Win screen
│   │   └── SettingsScreen.lua        # Settings menu
│   │
│   ├── ui/                           # ═══ UI COMPONENTS ═══
│   │   ├── components/
│   │   │   ├── Button.lua            # Reusable button
│   │   │   ├── Panel.lua             # UI panel/window
│   │   │   ├── Slider.lua            # Volume slider
│   │   │   ├── Checkbox.lua          # Toggle options
│   │   │   ├── ProgressBar.lua       # HP/XP bars
│   │   │   ├── Tooltip.lua           # Item tooltips
│   │   │   ├── Modal.lua             # Popup windows
│   │   │   └── Notification.lua      # Toast notifications
│   │   │
│   │   ├── hud/
│   │   │   ├── BattleHUD.lua         # HP, abilities, combo
│   │   │   ├── MinimapHUD.lua        # Minimap corner
│   │   │   └── QuestTracker.lua      # Quest objectives
│   │   │
│   │   └── animations/
│   │       ├── UITransition.lua      # Fade in/out
│   │       └── NumberPopup.lua       # Damage numbers
│   │
│   ├── effects/                      # ═══ VFX & JUICE ═══
│   │   ├── ParticleManager.lua       # Particle pooling
│   │   ├── ScreenShake.lua           # Camera shake effects
│   │   ├── FlashEffect.lua           # Screen flash (hit/heal)
│   │   ├── TrailRenderer.lua         # Motion trails
│   │   └── ExplosionEffect.lua       # Explosions
│   │
│   ├── audio/                        # ═══ AUDIO SYSTEM ═══
│   │   ├── AudioManager.lua          # Quản lý âm thanh
│   │   ├── MusicPlayer.lua           # Background music
│   │   ├── SFXPlayer.lua             # Sound effects
│   │   └── AudioMixer.lua            # Volume control
│   │
│   └── utils/                        # ═══ UTILITIES ═══
│       ├── math/
│       │   ├── Vector2.lua           # Vector math
│       │   ├── Collision.lua         # AABB, circle collision
│       │   └── Easing.lua            # Easing functions
│       │
│       ├── animation/
│       │   ├── Animator.lua          # Sprite animation
│       │   ├── Tween.lua             # Tweening library wrapper
│       │   └── StateMachine.lua      # Generic state machine
│       │
│       ├── helpers/
│       │   ├── Table.lua             # Table utilities
│       │   ├── String.lua            # String helpers
│       │   ├── Color.lua             # Color utilities
│       │   ├── Timer.lua             # Timer/cooldown
│       │   └── Pool.lua              # Object pooling
│       │
│       └── debug/
│           ├── DebugDraw.lua         # Draw hitboxes
│           ├── Console.lua           # In-game console
│           └── Profiler.lua          # Performance monitor
│
├── assets/                           # ═══ GAME ASSETS ═══
│   │
│   ├── images/
│   │   ├── characters/
│   │   │   ├── player/
│   │   │   │   ├── idle.png
│   │   │   │   ├── run.png
│   │   │   │   └── attack.png
│   │   │   ├── enemies/
│   │   │   │   └── (enemy sprites)
│   │   │   ├── bosses/
│   │   │   │   └── (boss sprites)
│   │   │   └── npcs/
│   │   │       └── (npc portraits)
│   │   │
│   │   ├── items/
│   │   │   ├── weapons/
│   │   │   ├── consumables/
│   │   │   └── equipment/
│   │   │
│   │   ├── ui/
│   │   │   ├── buttons/
│   │   │   ├── panels/
│   │   │   ├── icons/
│   │   │   └── fonts/
│   │   │
│   │   ├── effects/
│   │   │   ├── particles/
│   │   │   ├── explosions/
│   │   │   └── projectiles/
│   │   │
│   │   ├── backgrounds/
│   │   │   ├── battle/
│   │   │   ├── menu/
│   │   │   └── cutscenes/
│   │   │
│   │   └── tilesets/
│   │       └── (map tiles)
│   │
│   ├── audio/
│   │   ├── music/
│   │   │   ├── menu_theme.ogg
│   │   │   ├── battle_01.ogg
│   │   │   ├── boss_theme.ogg
│   │   │   └── victory.ogg
│   │   │
│   │   └── sfx/
│   │       ├── player/
│   │       │   ├── attack.wav
│   │       │   ├── hurt.wav
│   │       │   └── jump.wav
│   │       ├── ui/
│   │       │   ├── click.wav
│   │       │   └── hover.wav
│   │       └── combat/
│   │           ├── explosion.wav
│   │           └── hit.wav
│   │
│   ├── fonts/
│   │   ├── main.ttf                  # UI font
│   │   ├── dialogue.ttf              # Dialogue font
│   │   └── damage_numbers.ttf        # Số damage
│   │
│   ├── shaders/                      # Shader effects (optional)
│   │   ├── outline.glsl
│   │   ├── blur.glsl
│   │   └── chromatic.glsl
│   │
│   └── data/                         # ═══ GAME DATA ═══
│       │
│       ├── scenarios/                # Story scenarios
│       │   ├── prologue.json
│       │   ├── chapter_01.json
│       │   └── endings/
│       │       ├── true_ending.json
│       │       └── bad_ending.json
│       │
│       ├── dialogues/                # Dialogue scripts
│       │   ├── npc_merchant.json
│       │   ├── boss_dialogues.json
│       │   └── cutscenes/
│       │       ├── intro.json
│       │       └── finale.json
│       │
│       ├── items/                    # Item definitions
│       │   ├── weapons.json
│       │   ├── consumables.json
│       │   └── equipment.json
│       │
│       ├── enemies/                  # Enemy data
│       │   ├── common_enemies.json
│       │   └── bosses.json
│       │
│       ├── skills/                   # Skill definitions
│       │   ├── player_skills.json
│       │   └── boss_skills.json
│       │
│       ├── maps/                     # Map data
│       │   ├── overworld.json
│       │   ├── dungeon_01.json
│       │   └── boss_arenas/
│       │       └── demon_king_arena.json
│       │
│       ├── bullet_patterns/          # Danmaku patterns
│       │   ├── spiral.json
│       │   ├── circle_burst.json
│       │   └── custom_patterns.json
│       │
│       ├── cutscenes/                # Cutscene timelines
│       │   ├── intro_cutscene.json
│       │   └── boss_defeat.json
│       │
│       ├── achievements/
│       │   └── achievements.json
│       │
│       └── localization/             # Đa ngôn ngữ (future)
│           ├── en.json
│           └── vi.json
│
├── libs/                             # ═══ EXTERNAL LIBRARIES ═══
│   ├── middleclass.lua               # OOP (https://github.com/kikito/middleclass)
│   ├── hump/                         # Helpers (gamestate, timer, camera)
│   │   ├── gamestate.lua
│   │   ├── timer.lua
│   │   └── camera.lua
│   ├── anim8.lua                     # Sprite animation
│   ├── bump.lua                      # Collision detection
│   ├── STI.lua                       # Tiled map loader
│   ├── flux.lua                      # Tweening
│   ├── lume.lua                      # General utilities
│   ├── json.lua                      # JSON parser
│   └── inspect.lua                   # Debug printing
│
├── tools/                            # ═══ DEV TOOLS ═══
│   ├── map_editor/                   # Custom map tools (optional)
│   ├── dialogue_editor/              # Dialogue creator (optional)
│   └── build_scripts/
│       ├── build_win.bat
│       ├── build_mac.sh
│       └── build_linux.sh
│
└── docs/                             # ═══ DOCUMENTATION ═══
    ├── architecture.md               # Giải thích cấu trúc
    ├── coding_standards.md           # Code conventions
    ├── entity_reference.md           # Tài liệu entities
    ├── data_formats.md               # JSON schema
    └── ai_prompts/                   # Lưu prompts hiệu quả
        ├── entity_template.txt
        └── boss_pattern_template.txt#   h e r o _ g a m e  
 