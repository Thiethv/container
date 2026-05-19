# mobile_cont_approval

Flutter app riêng cho luồng manager duyệt Security Cont của THV qua Supabase.

## What It Does

- Đọc `public.security_cont_pending_requests` với `status = 'PENDING'`.
- Hiển thị chi tiết lỗi cont cho manager trên mobile.
- Ghi quyết định vào `public.security_cont_approval_events` với `action = approve|reject`.
- Không cập nhật `security_cont_pending_requests` trực tiếp từ app. Backend THV sẽ resolve sau khi local PG commit thành công.

## Run Locally

```bash
flutter pub get
flutter run -d chrome
```

App sẽ tự đọc file `.env` ở root của project. File hiện tại nên có tối thiểu:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
APP_TITLE=THV Cont Approval
PENDING_POLL_SECONDS=12
```

App cũng hỗ trợ fallback qua `--dart-define` nếu anh build từ CI mà không muốn giữ file `.env` trong repo.

Tuỳ chọn runtime:

- `--dart-define=PENDING_POLL_SECONDS=12` để đổi chu kỳ refresh pending list.
- `--dart-define=APP_TITLE="THV Cont Approval"` để đổi tên hiển thị trong app.

Nếu chưa có `SUPABASE_URL` hoặc `SUPABASE_ANON_KEY`, app vẫn build được và sẽ hiển thị màn hình hướng dẫn cấu hình.

## GitHub Pages Build

```bash
flutter pub get
flutter build web --release
```

Ghi chú cho script `deploy_to_github_pages.sh` của anh:

- App này giữ `web/index.html` với `<base href="/">` mặc định.
- Script GitHub Pages của anh đã tự rewrite base href sang `/$REPO_NAME/` sau khi build, nên không cần sửa thêm trong app.
- Vì `.env` được đóng gói thành Flutter asset khi build web, chỉ cần file `.env` tồn tại trước khi script chạy `flutter build web`.

Nếu CI không có file `.env`, có thể dùng fallback:

```bash
flutter build web --release \
	--dart-define=SUPABASE_URL=https://your-project.supabase.co \
	--dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## Supabase Contract

- Read: `public.security_cont_pending_requests`
- Insert: `public.security_cont_approval_events`
- `actor_username` phải khớp `core.users.username` ở local PG và user đó phải có `can_approve_cont = TRUE`.
- `action` phải là `approve` hoặc `reject`.
- `source` được app gửi là `MOBILE_APP`.

## Username And Auth

`actor_username` được backend local dùng để kiểm tra quyền duyệt cont trong PostgreSQL. Cụ thể, scheduler sẽ đọc `actor_username` từ `security_cont_approval_events` và map ngược về `core.users.username` ở local PG. Nếu không tìm thấy user đó, hoặc user đó không có `can_approve_cont = TRUE`, event sẽ bị đánh `ERROR` và không áp dụng vào local PG.

Hiện app Flutter này đang chạy ở `manual username mode`:

- Manager tự nhập username local PG trong app.
- Supabase không bắt buộc phải có bảng user riêng để app chạy.
- Đây là cách nhanh nhất để chạy nội bộ với GitHub Pages.

Nếu muốn RLS production chặt chẽ hơn, anh nên dùng Supabase Auth và bảng mapping user. Tôi đã thêm SQL trong [../docs/be/security-cont-mobile-rls.sql](../docs/be/security-cont-mobile-rls.sql):

- `quick-start internal mode`: app hiện tại dùng được ngay, không cần login Supabase.
- `production authenticated mode`: cần tạo bảng mapping `security_cont_mobile_users` và chỉ cho user đã login Supabase đọc/ghi dữ liệu.

## GitHub Notes

- `SUPABASE_ANON_KEY` là client key public, có thể xuất hiện ở web build. Không dùng service-role key trong Flutter app.
- Nếu app đọc/ghi trực tiếp Supabase từ GitHub Pages, phải bật RLS cho 2 table liên quan.
- Nếu anh đã lỡ commit `.env`, điều đó không làm lộ thêm gì ngoài anon key public. Tuy nhiên tuyệt đối không đưa service-role key vào file này.

## Smoke Test

```bash
flutter analyze
flutter test
flutter build web --release
```
