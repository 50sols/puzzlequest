# حالة ملفات Android / iOS

- توجد ملفات المصدر الأصلية للمنصتين (Gradle/Manifest/Kotlin وPodfile/Swift/Plist/Storyboards/Icons).
- لا يوجد **gradle-wrapper.jar** في البيئة ولا **ios/Runner.xcodeproj**: كلاهما يولده Flutter SDK/Xcode عند تشغيل `tool/prepare_platforms.py` على جهاز مطور، ويجب إعادة فحصهما قبل الإصدار.
- Firebase client JSON/Plist موجودان، لكن Google Native OAuth + APNs + FCM backend credentials + production AdMob App IDs غير معتمدة بعد.
- لا تنشر إعلانات العينة الموجودة في AndroidManifest على Production؛ مسار CI يمنع اعتبار الخدمات مفعّلة دون إعدادها.
- ملفات التوقيع وملفات Provisioning / Keystore غير مشمولة لأسباب أمنية.
