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

### เปลี่ยนรหัสผ่านของ Strapi Admin

`ADMIN_PASSWORD` ใน `.env` เป็นค่าที่ REST Client อ่านเท่านั้น ไม่ใช่การตั้งค่าของ Strapi
การเปลี่ยนค่าใน `.env` จึงไม่เปลี่ยนรหัสที่เก็บอยู่ใน `admin_users` ต้องรันคำสั่งนี้หลังเปลี่ยนรหัส:

```bash
./scripts/sync-admin-password.sh
```

ถ้าไม่รัน `/admin/login` จะตอบ `Invalid credentials` และทั้งหัวข้อ 3 ใน `api.http`
จะได้ 401 เพราะสร้าง API token ไม่ได้

### ข้อจำกัดที่ยังต้องตั้งค่าเพิ่ม

ยังไม่ได้ตั้ง SMTP ในโปรเจกต์นี้ Strapi จึงส่งอีเมลไม่ได้ ทำให้ `forgot-password`
ตอบ `504` ภายใน 10 วินาที (nginx ตัดเวลาไว้ไม่ให้ค้าง) และ `reset-password` ทำต่อไม่ได้
เพราะไม่มี reset code ส่วนหัวข้อ 3 ไม่เกี่ยวกับอีเมล จึงใช้งานได้ครบทั้ง 12 call

## ทดสอบ REST API

เปิด `api.http` ด้วย VS Code REST Client แล้วรันทีละ request ตามลำดับ
(ดูรายละเอียดของแต่ละหัวข้อได้ในคอมเมนต์ในไฟล์)

หัวข้อ 3 ไม่ต้องเตรียมอะไรเพิ่ม ตัวไฟล์จะสร้าง API token ให้เองที่ `Prereq.1`
และใช้กับทุก call ใน 3.1-3.3 อัตโนมัติ (token มีอายุ 7 วัน)