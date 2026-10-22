# مهامي 🗂️

منظم مهام وملاحظات شخصي لـ **macOS** — **عربي بالكامل (RTL)** — مبني بـ SwiftUI + SwiftData مع مزامنة **iCloud (CloudKit)**.

# إهداء إلى المستخدم العربي

### Thanks for OOMestre , original project : https://github.com/OOMestre/Focenda

## ✨ الميزات

- **اللوحة الرئيسية** — المهام البارزة والمستحقة قريبًا في نظرة واحدة
- **المهام** — لوحة كانبان (تطوير / نحو التنفيذ / مكتملة) + عرض قائمة، بترتيب ذكي: التاريخ ← الأولوية ← الأحدث
- **المشاريع** — تجميع المهام مع شريط تقدم حي
- **الملاحظات** — داخل مجلدات، والتحرير بالنقر المزدوج
- **التذكيرات** — تنبيهات النظام مع مواعيد مرنة
- **العلامات المرجعية** — روابط مصنفة مع عدّاد الزيارات والتعديل بالنقر المزدوج
- **ملاحظة سريعة** — نافذة عائمة تفتح بـ ⌘O وتحفظ تلقائيًا
- **مزامنة iCloud** — عبر حاوية CloudKit خاصة، مع تراجع محلي آمن
- **نسخ احتياطي** — تصدير/استيراد JSON كامل للبيانات
- **وضع داكن** — يتبع النظام في كل نافذة

## 🖼️ لقطات الشاشة

| | |
|:---:|:---:|
| <img src="images/mainimg.png" width="400" alt="اللوحة الرئيسية"> <br> **اللوحة الرئيسية** | <img src="images/tasksimg.png" width="400" alt="المهام"> <br> **المهام (كانبان)** |
| <img src="images/calimg.png" width="400" alt="التقويم"> <br> **التقويم** | <img src="images/notesimg.png" width="400" alt="الملاحظات"> <br> **الملاحظات** |
| <img src="images/reminderimg.png" width="400" alt="التذكيرات"> <br> **التذكيرات** | <img src="images/reminderimg2.png" width="400" alt="تفاصيل التذكير"> <br> **تفاصيل التذكير** |
| <img src="images/bookmarksimg.png" width="400" alt="العلامات المرجعية"> <br> **العلامات المرجعية** | <img src="images/quicknoteimg.png" width="320" alt="الملاحظة السريعة"> <br> **الملاحظة السريعة ⌘O** |
| <img src="images/settingimg.png" width="400" alt="الإعدادات"> <br> **الميزات والإعدادات** | <img src="images/aboutimg.png" width="400" alt="حول التطبيق"> <br> **حول التطبيق** |

## 🛠️ التقنيات

| | |
|---|---|
| الواجهة | SwiftUI |
| البيانات | SwiftData + CloudKit (CloudKit-backed container) |
| اللغة | Swift 5 / Swift Concurrency |
| الهدف | macOS 15+ |
| عربي | RTL كامل، أرقام غربية، سلسلة أدوات عربية مخصصة |

## 📦 البناء

```bash
cd "My Tasks"
xcodebuild -project "مهامي.xcodeproj" -scheme "مهامي" -configuration Debug build \
  -allowProvisioningUpdates
```

يتطلب البناء حساب Apple Developer لعمل المزامنة السحابية (CloudKit container: `iCloud.com.devpro.mytasks`).

## 📁 البنية

```
مهامي/
├── MyTasksApp.swift      # نقطة الإطلاق + مخطط البيانات + الترحيل
├── Classes/              # النماذج، المساعدات، النسخ الاحتياطي
├── Views/                # الشاشات (مهام، ملاحظات، تذكيرات، علامات، إعدادات، ملاحظة سريعة)
├── FormControls.swift    # عناصر واجهة مخصصة
└── مهامي.entitlements    # iCloud/CloudKit
AppStore/                 # معلومات جاهزة للنشر على App Store
```

## 📃 الترخيص

راجع ملف [LICENSE](مهامي/LICENSE).

---

صُنع بحب في الكويت 🇰🇼
