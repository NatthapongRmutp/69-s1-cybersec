<div align="center">

# Cyber Security

สาขาความปลอดภัยไซเบอร์ และการรับมือภัยคุกคามทางดิจิทัล

</div>

---

## Information

| รายการ | รายละเอียด |
| :--- | :--- |
| รหัสนักศึกษา | 076-1 |
| รหัสวิชา | 69-s1-cybersec |

## ความคาดหวังของวิชานี้

- ต้องการเรียนรู้ด้าน Cyber Security ทั้งภาคทฤษฎีและภาคปฏิบัติ
- สามารถนำความรู้ไปประยุกต์ใช้ในการป้องกันระบบและการทดสอบความปลอดภัยได้
- พัฒนาทักษะการใช้เครื่องมือที่เกี่ยวข้องกับความมั่นคงปลอดภัยไซเบอร์

## การติดตั้ง

```bash
cp env.simple .env      # แก้ค่าใน .env ให้เป็นของจริงก่อน (รวมถึงค่า secret 5 ตัวท้าย ๆ)
docker compose up -d
```

| Service | Port | การเข้าถึง |
| :--- | :--- | :--- |
| nginx (reverse proxy) | `API_PORT` (80) | ทุกอย่างเข้าผ่านที่นี่ |
| Strapi (debug) | `APP_PORT` (9092) | `127.0.0.1` เท่านั้น |
| PostgreSQL | `POSTGRES_PORT` (5432) | `127.0.0.1` เท่านั้น |
| pgAdmin | `PGADMIN_DEFAULT_PORT` (8082) | `127.0.0.1` เท่านั้น |

หมายเหตุ: Strapi เชื่อมต่อฐานข้อมูลด้วย user `DATABASE_USERNAME` ที่สร้างจาก `db/init.sh`
ซึ่งไม่ใช่ superuser — ถ้าเข้าผ่าน `APP_PORT` ตรง ๆ จะไม่ผ่าน rate limiting ของ nginx

### อัปเกรดจากเวอร์ชันที่ใช้ user เดิม (สำคัญ)

`db/init.sh` จะรันอัตโนมัติเฉพาะตอนสร้าง volume ใหม่เท่านั้น ถ้าคุณมี volume เดิมอยู่แล้ว
Strapi จะขึ้น `password authentication failed for user "strapi"` ให้รันครั้งเดียวเพื่อซ่อม:

```bash
docker compose exec db bash /docker-entrypoint-initdb.d/10-init.sh
```

สคริปต์นี้ idempotent (รันซ้ำได้) และจะย้าย ownership ของตารางเดิมมาให้ user ใหม่โดยไม่ลบข้อมูล

### เปลี่ยนรหัสผ่านของบัญชี

`ADMIN_PASSWORD` และ `USER_PASSWORD` ใน `.env` เป็นค่าที่ REST Client อ่านเท่านั้น
ไม่ใช่การตั้งค่าของ Strapi การเปลี่ยนค่าใน `.env` จึงไม่เปลี่ยนรหัสที่เก็บอยู่ใน
`admin_users` / `up_users` ต้องรันคำสั่งนี้หลังเปลี่ยนรหัส หรือหลัง clone ใหม่:

```bash
./scripts/sync-credentials.sh
```

ถ้าไม่รัน จะได้ `Invalid credentials` และทั้งสอง chain ใน `api.http` จะพัง:
หัวข้อ 1 → `Prereq.1` → หัวข้อ 3 ได้ 401 และหัวข้อ 2 (`2.1` → `2.4`) จะไม่มี JWT ใช้

หมายเหตุ: สคริปต์นี้จะอัปเดตรหัสของบัญชีที่มีอยู่แล้วเท่านั้น ไม่สร้างหรือลบบัญชี
ถ้ายังไม่มีบัญชีผู้ใช้ ให้รัน `2.2 Register` ใน `api.http` ก่อน แล้วค่อยรันสคริปต์ซ้ำ

### ข้อจำกัดที่ยังต้องตั้งค่าเพิ่ม

ยังไม่ได้ตั้ง SMTP ในโปรเจกต์นี้ Strapi จึงส่งอีเมลไม่ได้ `forgot-password` จึงตอบ
`504` ภายใน 10 วินาที (nginx ตัดเวลาไว้ไม่ให้ค้าง)

แต่ Strapi เขียน reset code ลงฐานข้อมูล **ก่อน** พยายามส่งเมล ดังนั้นยังทำต่อได้
โดยดึง code จากฐานข้อมูลแล้วนำไปใส่ใน `2.3.1`:

```sql
SELECT reset_password_token FROM up_users WHERE email = '<USER_EMAIL ของคุณ>';
```

ส่วนหัวข้อ 3 ไม่เกี่ยวกับอีเมล จึงใช้งานได้ครบทั้ง 12 call

## ทดสอบ REST API

เปิด `api.http` ด้วย VS Code REST Client แล้วรันทีละ request ตามลำดับ
(ดูรายละเอียดของแต่ละหัวข้อได้ในคอมเมนต์ในไฟล์)

หัวข้อ 3 ไม่ต้องเตรียมอะไรเพิ่ม ตัวไฟล์จะสร้าง API token ให้เองที่ `Prereq.1`
และใช้กับทุก call ใน 3.1-3.3 อัตโนมัติ (token มีอายุ 7 วัน)

### ค่าที่ unique ต้องเปลี่ยนทุกครั้งที่รันซ้ำ

`student.mobile`, `student.cardId` และ `subject.name` เป็น unique ใน Content-Type Builder
ถ้าใส่ค่าเดิมซ้ำจะได้ `400 This attribute must be unique` — ซึ่งเป็นผลที่ถูกต้อง
ตามข้อ 2.2/1.2 ที่รันซ้ำไม่ได้เช่นกัน ถ้าจะทดสอบซ้ำให้แก้ค่าใน `.env` แล้วรันใหม่

### ระบุ record ที่จะดึง/แก้

`3.x.3` และ `3.x.4` อ่าน id จาก `STUDENT_ID` / `SUBJECT_ID` / `TEACHER_ID` ใน `.env`
(ผูกเป็น `@student_id` / `@subject_id` / `@teacher_id` ในบล็อก `## Variables` ของ `api.http`)
จึงไม่ต้องรัน `3.x.1` ก่อน และรันซ้ำได้โดยไม่ชน unique

ดูค่า id ที่มีอยู่ได้จาก response ของ `3.x.1` หรือเปิด pgAdmin ที่ `http://127.0.0.1:8082`
แล้วดูคอลัมน์ `id` ในตาราง `students` / `subjects` / `teachers`
