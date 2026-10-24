# Maple Godot

Bản Godot 4 của [Maple PC](../maple-pc/README.md): game hành động màn hình
ngang lấy cảm hứng từ MapleStory M. Logic game (vật lý, chiến đấu, quái, boss,
tự động săn) được chuyển từ bản JavaScript sang GDScript. Phần hình ảnh lấy từ
APK của chính bạn khi đã tách hình.

_Godot 4 port of Maple PC. Visuals use art extracted locally from your own
MapleStory M APK; that art is git-ignored and never committed._

## Hình từ APK

APK MapleStory M chỉ chứa hình của launcher và giao diện. Hình nhân vật lúc
chơi và hình bản đồ được game tải từ máy chủ sau khi đăng nhập, nên APK không
có. Bản Godot dùng:

| Hình trong APK                         | Dùng cho                                   |
| -------------------------------------- | ------------------------------------------ |
| `game_start_bg`                        | Nền màn hình bắt đầu                       |
| `DownloadScene_*` (nhân vật toàn thân) | Ngoại hình nhân vật khi chơi (10 lựa chọn) |
| `Creating_CharactersAtlas`             | Chân dung nghề ở màn chọn nghề và trên HUD |
| `26_SkillButtonAtlas`                  | Khung nút kỹ năng, nút đánh thường         |
| `HPBarMonster`                         | Thanh máu quái                             |

Quái, bản đồ và hiệu ứng vẫn được vẽ bằng code. Nếu chưa tách hình, game vẫn
chạy và tự vẽ thay toàn bộ.

Hình thuộc về Nexon. Thư mục `assets/apk/` nằm trong `.gitignore`, nên chỉ giữ
trên máy của bạn và không đưa lên repo.

### Tách hình

Cần Python 3.9 trở lên:

```bash
pip install UnityPy Pillow
python tools/extract_apk_assets.py "D:/đường/dẫn/MapleStory M.xapk"
```

Script nhận file `.xapk` hoặc `.apk` gốc và ghi kết quả vào `assets/apk/`. Vị
trí các hình trong atlas được chọn theo bản 2.450.5776. Với bản khác, nếu một
hình bị lệch, chỉ cần sửa `PICKS` trong script.

## Chạy game

1. Mở Godot 4 (từ 4.2 trở lên), chọn **Import**, rồi chọn
   `games/maple-godot/project.godot`.
2. Nhấn **F5** để chạy.

Có thể chạy bằng dòng lệnh: `godot --path games/maple-godot`.

Hình từ APK được nạp lúc chạy từ `assets/apk/`. Vì vậy cần chạy từ project
này. Nếu muốn export ra file `.exe`, hãy thêm `assets/apk/*` vào mục _Filters
to export non-resource files_ trong preset export.

## Test

```bash
godot --headless --path games/maple-godot --script res://tests/run_tests.gd
```

Lệnh này chạy 12 test logic: EXP, sát thương, cường hóa, bản đồ, nhảy, leo
thang, nhảy xuống, giết quái và nhặt đồ, bắn xuyên, cổng, tự động săn cho cả 5
nghề, và boss.

## Điều khiển

Giống Maple PC: ← → di chuyển, ↑ ↓ leo thang hoặc vào cổng, Space hoặc C để
nhảy (nhảy đôi trên không), ↓ + Space để nhảy xuống tầng dưới, Z đánh thường,
A S D F kỹ năng, Q W thuốc, T tự động săn, U cường hóa vũ khí, P hoặc Esc tạm
dừng, H hướng dẫn. Có thể bấm chuột vào các nút trên HUD.

## Cấu trúc

```
scenes/main.tscn          scene gốc
scripts/main.gd           input, chuyển menu và game, lưu game
scripts/menu.gd           màn hình bắt đầu: tên, nghề, ngoại hình
scripts/game_data.gd      dữ liệu, sinh từ maple-pc/src/data.js (tools/sync_data.py)
scripts/rules.gd          hằng số vật lý, công thức sát thương, EXP, cường hóa
scripts/map_physics.gd    foothold một chiều, thang, trọng lực
scripts/player.gd         nhân vật
scripts/monster.gd        quái và boss
scripts/auto_battle.gd    tự động săn
scripts/world.gd          mô phỏng bản đồ: kỹ năng, sát thương, rơi đồ, cổng
scripts/world_view.gd     vẽ thế giới, camera
scripts/background.gd     bầu trời, núi parallax
scripts/hud.gd            giao diện
scripts/apk_assets.gd     nạp hình từ assets/apk/ (có thể thiếu)
tools/extract_apk_assets.py  tách hình từ APK
```

Để sửa nghề, quái hoặc bản đồ, hãy sửa `games/maple-pc/src/data.js`, rồi chạy
`python tools/sync_data.py` để cả hai bản dùng chung một dữ liệu.
