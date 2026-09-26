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

## ทดสอบ REST API

เปิด `api.http` ด้วย VS Code REST Client แล้วรันทีละ request ตามลำดับ
(ดูรายละเอียดของแต่ละหัวข้อได้ในคอมเมนต์ในไฟล์)