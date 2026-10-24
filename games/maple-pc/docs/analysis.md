# Phân tích client MapleStory M

Ghi chú từ việc mở gói `MapleStory M 2.450.5776` (XAPK từ APKPure) và xem video
gameplay "Nấm Đại Chiến". Mục đích là hiểu cấu trúc và cơ chế để dựng lại lối
chơi; không có tài nguyên hay dữ liệu nào từ gói được đưa vào game.

## Gói cài đặt

| Mục       | Giá trị                                                   |
| --------- | --------------------------------------------------------- |
| Package   | `com.nexon.maplem.global`                                 |
| Engine    | Unity 2022.3.62f2, scripting backend IL2CPP               |
| Kiến trúc | arm64-v8a (`libil2cpp.so` khoảng 267 MB, `libunity.so`)   |
| Metadata  | `global-metadata.dat` 54 MB, magic `AF1BB1FA`, version 31 |
| Bảo mật   | `libngsm.so`, `libngsme.so` (anti-cheat của Nexon)        |
| Khác      | Firebase (Analytics, Crashlytics, Messaging), `libhpatch` |

Gói APK chỉ chứa phần khởi động (`assets/bin/Data` khoảng 140 MB, phần lớn là
split asset). Bản đồ, quái và bảng số liệu được tải về từ máy chủ sau khi
đăng nhập, nên các con số cụ thể (máu quái, hệ số kỹ năng) không có trong APK.

`global-metadata.dat` không bị mã hóa, nên tên lớp và tên trường đọc được.
Một số nhóm tên dùng để định hướng thiết kế:

- Di chuyển: `Gravity`, `FallSpeed`, `JumpPower`, `JumpSpeed`, `JumpCount`,
  `JumpHeight`. Nhân vật có số lần nhảy (nhảy đôi) và trọng lực riêng.
- Bản đồ: `Foothold`, `FootholdList`, `FootholdNext`, `Ladder`, `LadderLine`,
  `Portal`, `PortalType`. Bản đồ là các đoạn foothold nối nhau, thêm thang và
  cổng, giống MapleStory PC.
- Chế độ tự động: `AutoBattle`, `AutoHunt`, `AutoHpPotion`, `AutoBuff`,
  `AutoBuffPet`, `AutoHpMpPotionPet`. Tự săn, tự uống thuốc và tự buff là cơ
  chế chính.
- Nhân vật: `JobType`, `JobCode`, `JobGroupName`, `ClassType`, cùng tên các
  nghề như `Warrior`, `Bowman`, `Pirate`, `Mercedes`, `Phantom`, `Luminous`,
  `Kaiser`, `Illium`.
- Chỉ số: `MaxHp`, `MaxMp`, `Accuracy`, `Defense`, `CriticalDamage`,
  `BossDamage`.
- Cường hóa: `AutoEnchantButton`, `AutoChangeOptionMaxPotentialGrade`,
  `AutoChangeOptionMaxCubeCount` (cường hóa sao và tiềm năng).

## Video gameplay

Video dài khoảng 4 phút, 1920x1080, chủ yếu là trận boss Lucid:

- Màn hình ngang, nhân vật nhỏ, nền nhiều lớp parallax (trăng, bướm).
- Góc trái trên: cấp, tên, HP/MP, lực chiến. Góc phải trên: bản đồ nhỏ, các
  biểu tượng buff ở hàng trên cùng.
- Giữa trên: tên boss, thanh HP, đồng hồ đếm ngược. Thông báo cảnh báo trước
  đòn mạnh của boss ("Lucid is about to use a powerful attack! Dodge!").
- Góc phải dưới: các nút kỹ năng tròn có thời gian hồi. Góc trái dưới: joystick
  (trên PC thay bằng bàn phím).
- Số sát thương lớn, xếp chồng theo từng đòn, có kiểu chí mạng riêng.
- Thanh EXP chạy hết chiều ngang ở đáy màn hình.

## Áp dụng vào bản PC

| Cơ chế client                 | Bản PC                                           |
| ----------------------------- | ------------------------------------------------ |
| Foothold, thang, cổng         | `src/physics.js`, dữ liệu bản đồ trong `data.js` |
| JumpCount                     | Nhảy đôi (`JUMP_COUNT = 2`)                      |
| AutoBattle/AutoHunt           | `src/ai.js`, phím T                              |
| Auto HP/MP potion, AutoBuff   | Trong `MS.autoInput`                             |
| Job branches                  | 5 nghề Explorer trong `MS.JOBS`                  |
| Enchant                       | Cường hóa vũ khí +15, phím U                     |
| Boss timer, cảnh báo đòn mạnh | Hang Nấm Vua, `bossTimeLimit`, `world.notice`    |

Các hằng số vật lý và số liệu cân bằng là ước lượng theo video, không phải giá
trị gốc.
