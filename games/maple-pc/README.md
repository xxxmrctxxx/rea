# Maple PC

Game hành động màn hình ngang 2D cho PC, lấy cảm hứng từ MapleStory M. Lối chơi
được dựng lại từ video gameplay và từ phân tích client Android bằng REA (xem
[docs/analysis.md](docs/analysis.md)). Toàn bộ hình ảnh được vẽ bằng code, nên
game không chứa tài nguyên, tên hay dữ liệu gốc của Nexon.

_A PC side-scrolling action RPG inspired by MapleStory M. Gameplay is rebuilt
from reference video and REA notes on the Android client; all art is drawn
procedurally and no original assets are shipped._

## Chạy game

Cần Node.js 22 trở lên.

```bash
cd games/maple-pc
npm install
npm start          # mở cửa sổ game (Electron)
```

Chơi trong trình duyệt thay vì cửa sổ riêng:

```bash
npm run serve      # mở http://localhost:5173
```

Chạy test logic (không cần cài gì thêm):

```bash
npm test
```

## Điều khiển

| Phím      | Chức năng                      |
| --------- | ------------------------------ |
| ← →       | Di chuyển                      |
| ↑ / ↓     | Leo thang, vào cổng (↑)        |
| Space / C | Nhảy, nhấn lần nữa để nhảy đôi |
| ↓ + Space | Nhảy xuống tầng dưới           |
| Z         | Đánh thường                    |
| A S D F   | Kỹ năng 1 đến 4                |
| Q / W     | Thuốc HP / MP                  |
| T         | Bật/tắt tự động săn            |
| U         | Cường hóa vũ khí (tốn meso)    |
| P / Esc   | Tạm dừng                       |
| H         | Ẩn/hiện bảng hướng dẫn         |

Có thể bấm chuột vào nút kỹ năng, thuốc và AUTO trên màn hình.

## Nội dung bản đầu tiên

- 5 nhánh nghề Explorer: Chiến Binh, Pháp Sư, Cung Thủ, Đạo Tặc, Hải Tặc. Mỗi
  nghề có đòn đánh thường và 4 kỹ năng (đánh vùng, bắn xuyên, lướt, dịch
  chuyển, buff).
- 3 bản đồ: Đồi Nấm, Rừng Nấm Sâu và phòng boss Hang Nấm Vua có giới hạn 10
  phút. Boss có đòn dậm đất (nhảy lên để né), lao tới và gọi thuộc hạ.
- Tầng nền một chiều, thang leo, nhảy đôi, nhảy xuống tầng dưới, cổng dịch
  chuyển giữa các bản đồ.
- Tự động săn giống chế độ Auto của bản mobile: tự tìm quái, leo thang, dùng
  kỹ năng, buff và uống thuốc.
- Nhặt đồ tự động, meso, thuốc, lên cấp, cường hóa vũ khí +15 với tỉ lệ thành
  công giảm dần.
- Giao diện theo bố cục bản mobile: trạng thái góc trái, bản đồ nhỏ góc phải,
  thanh máu boss và đồng hồ ở giữa, vòng kỹ năng góc phải dưới, thanh EXP.
- Tự lưu tiến trình mỗi 10 giây và khi chuyển bản đồ.

## Cấu trúc

```
games/maple-pc/
  index.html, style.css   màn hình chọn nghề và canvas
  src/core.js             namespace MS, RNG, hằng số vật lý
  src/data.js             nghề, kỹ năng, quái, vật phẩm, bản đồ
  src/physics.js          foothold một chiều, thang, trọng lực
  src/combat.js           công thức sát thương, EXP, cường hóa
  src/entities.js         nhân vật và quái (kể cả AI boss)
  src/ai.js               tự động săn
  src/world.js            sinh quái, kỹ năng, rơi đồ, cổng, boss
  src/render.js, hud.js   vẽ thế giới và giao diện
  src/input.js, main.js   bàn phím, lưu game, vòng lặp
  electron/main.mjs       cửa sổ desktop
  test/                   test logic chạy bằng node --test
```

Các file trong `src/` là script thường gắn vào `globalThis.MS`, nên game chạy
được mà không cần bundler, và test Node nạp đúng các file đó.

## Thêm nội dung

- Quái mới: thêm vào `MS.MONSTERS` trong `src/data.js` (hình dạng có sẵn:
  `mushroom`, `snail`, `slime`, `pig`).
- Bản đồ mới: thêm vào `MS.MAPS` với `footholds`, `ladders`, `portals`,
  `spawns`. Test `maps are consistent` kiểm tra thang và cổng có nối đúng không.
- Kỹ năng mới: thêm vào `skills` của nghề, chọn `kind` là `hit`, `projectile`,
  `dash`, `teleport` hoặc `buff`.
