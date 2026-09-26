import 'package:flutter/material.dart';

/// توكنز هوية فكرني — الجدول الكامل من `design/handoff/README.md`.
///
/// **كل hex وكل مقاس من هنا، ومفيش hex بيتكتب مرتين.** الذهبي محجوز
/// للتذكير والحالة النشطة فقط؛ الأحمر للطوارئ فقط — شاشتين الطوارئ
/// (`features/emergency/`) وبس.
abstract final class F {
  // ------------------------------------------------------------- الوضع
  /// الوضع الليلي — مفتاح واحد في الشريط العلوي، ومتخزّن محلياً
  /// (`shared_preferences`، زي عدّاد المية — مش في السكيما).
  ///
  /// الأسطح والنصوص تحت **getters** مش ثوابت عشان الشاشات ما تتغيّرش:
  /// نفس الاسم بيدي لون الوضع الحالي، والجذر بيعيد البناء مع [darkMode].
  static final ValueNotifier<bool> darkMode = ValueNotifier<bool>(false);

  static bool get isDark => darkMode.value;

  static void setDark({required bool on}) => darkMode.value = on;

  static Color _mode(Color light, Color dark) => isDark ? dark : light;

  // ------------------------------------------------------------- الألوان
  static const inkLight = Color(0xFF122E28);
  static const inkDark = Color(0xFFECF1EF);

  /// نص المتن — بيقلب مع الوضع.
  static Color get ink => _mode(inkLight, inkDark);
  static const greenLight = Color(0xFF10715E);
  static const greenOnDark = Color(0xFF4FBFA5);

  /// الأخضر اللي بيتكتب بيه ويترسم — بيفتح في الليل عشان يفضل مقروء.
  static Color get green => _mode(greenLight, greenOnDark);
  static const greenDeep = Color(0xFF0A4638);
  static const inkDeep = Color(0xFF071A16);
  static const greenDark = Color(0xFF0F3A31);

  /// التذكير والحالة النشطة **بس**.
  static const gold = Color(0xFFE9A93B);
  static const goldSoft = Color(0xFFF1C476);

  /// نص ذهبي على أرضية غامقة.
  static const goldText = Color(0xFFF0D3A0);

  /// اللوحة الخام — **ما تتكتبش في شاشة**. الشاشات بتاخد الأسطح الدلالية
  /// تحت (`pageGround` / `cardGround` / …)، عشان تغيير أرضية التطبيق كله
  /// يبقى سطرين هنا مش ١٣٠ موضع.
  /// `no_raw_surface_test` بيقع لو `Colors.white` أو `F.ivory*` ظهرت
  /// برّه الملف ده.
  static const white = Color(0xFFFFFFFF);
  static const ivory = Color(0xFFF1EFE6);
  static const ivoryWarm = Color(0xFFEAE7DB);
  static const ivoryPale = Color(0xFFF7F5EC);
  static const ivoryDim = Color(0xFFEFEDE3);

  /// رمادي الكروت من المخططات (٠٤-home) — الكارت بيبان على الأبيض من غير حد.
  static const cardGrey = Color(0xFFEFEFEF);

  /// السطح الأهدى (٠٢ و٠٣) — لوح جوّه كارت، أو صف معطّل.
  static const quietGrey = Color(0xFFF6F6F6);

  // ------------------------------------------------------- الأسطح الدلالية
  /// أرضية الشاشة — أبيض المخططات في النهار، أخضر شبه أسود في الليل.
  /// **تغيير أرضية التطبيق كله من السطر ده.**
  static Color get pageGround => _mode(white, const Color(0xFF0E1513));

  /// الكارت اللي فوق أرضية الشاشة — رمادي المخططات، بيبان من غير حد.
  static Color get cardGround => _mode(cardGrey, const Color(0xFF182220));

  /// لوح هادي: جوّه كارت، شريحة، صف معطّل، خلفية شريط.
  static Color get railGround => _mode(quietGrey, const Color(0xFF1F2A27));

  /// حقل إدخال — أوضح سطح في وضعه، وله حد.
  static Color get fieldGround => _mode(white, const Color(0xFF131B19));

  /// أرضية الديالوج — أوضح سطح فوق أي شاشة.
  static Color get dialogGround => _mode(white, const Color(0xFF1B2421));

  /// المية (D3.2): أزرق **محجوز للمية وبس** — مش لون عام في الهوية.
  static Color get waterGround => _mode(const Color(0xFFE3F1F8), const Color(0xFF12303E));
  static Color get waterInk => _mode(const Color(0xFF17627F), const Color(0xFFBFE3F5));
  static const waterDrop = Color(0xFF3FA3D6);

  /// «معلومة تهمك» (٢٤ سبتمبر ٢٠٢٦، طلب المالك): أزرق فاتح جداً لكارت
  /// المعلومة اللي أخد مكان كارت المية — نفس العايلة، أفتح منها، ومعرّف
  /// مرة واحدة هنا. النص عليه `ink` (متقاس في `dark_mode_test`).
  static Color get tipSurface => _mode(const Color(0xFFEAF4FC), const Color(0xFF14283A));

  /// اللمبة على كارت المعلومة — بتنوّر وتطفي بالتوهّج، مش بالحجم.
  static Color get tipGlow => _mode(const Color(0xFF2F86C9), const Color(0xFF7CC0F0));

  /// نص وأيقونات على أرضية غامقة (أخضر، أو صورة الكاميرا).
  static const onDark = white;

  /// نفس ده، بس ثانوي — لسه فوق ٤.٥:١ على الأخضر الغامق.
  static const onDarkMuted = ivoryWarm;

  /// أرضية الاختيار المتحدّد (المخطط ٢): أخضر فاتح جداً على الأبيض.
  static Color get greenTint => _mode(const Color(0xFFEAF3F0), const Color(0xFF1E3A33));

  static Color get line => _mode(const Color(0xFFDFDACB), const Color(0xFF2C3A36));
  static Color get lineSoft => _mode(const Color(0xFFE9E5D8), const Color(0xFF243029));

  /// أيقونات وفواصل — **مش نص** (٣.٦٨:١ على الكارت الفاتح).
  static Color get muted => _mode(const Color(0xFF6E7F76), const Color(0xFF90A09A));

  /// النص الثانوي — ٨:١ على الفاتح، ٩:١ على الغامق.
  static Color get mutedDark => _mode(const Color(0xFF43544C), const Color(0xFFB7C4BF));

  static Color get mutedLight => _mode(const Color(0xFF8B9C93), const Color(0xFF6E7F76));
  static Color get placeholder => _mode(const Color(0xFFA5AFA5), const Color(0xFF7E8C86));

  /// درجات السلّم ٣ و٤ — للتنبيه المتصاعد (D2)، مش لأي حاجة تانية.
  static const amber = Color(0xFFD3A21C);
  static const orange = Color(0xFFD9691F);

  /// **الطوارئ بس** (D3.4): زرار الإسعاف وأرضية شاشة الطوارئ. ولا لون من
  /// دول بيظهر برّه `features/emergency/` — اختبار بيقرا الكود ويوقع لو حصل.
  static const red = Color(0xFFC0202F);
  static const redDeep = Color(0xFFA81E26);

  /// لوح أغمق على أرضية الطوارئ (الحساسية وجهات الاتصال).
  static const redPanel = Color(0xFF8C1820);

  /// النص على الأحمر — أبيض، والثانوي أبيض شفّاف شوية (لسه فوق ٤.٥:١).
  static const onRed = Color(0xFFFFFFFF);
  static const onRedMuted = Color(0xE6FFFFFF);

  /// **الاستثناء الوحيد للأحمر برّه الطوارئ**: قيمة تحليل برّه النطاق
  /// المطبوع على ورقة المعمل — نص وإطار، **عمره ما يبقى حشو**. الحبّاية
  /// الحمرا المليانة فاضلة للطوارئ لوحدها، وده اللي بيخلي معناها محفوظ؛
  /// اللي هنا علامة على مقارنة بين رقمين مطبوعين، مش نداء استغاثة.
  /// مكانه الوحيد في الكود `features/health/lab_flag.dart`.
  ///
  /// getter مش ثابت زي باقي ألوان النص: `red` نفسه ٢.٧١:١ على كارت الليل —
  /// تحت AA بكتير — فالوضع الغامق بياخد أحمر فاتح (٥.٦٠:١ على الكارت،
  /// ٦.٣٦:١ على الصفحة). في النهار `red` زي ما هو (٦.٠٢:١ و٥.٢٣:١).
  static Color get outOfRangeInk => _mode(red, const Color(0xFFE8747B));

  /// اتأكدت / اتاخدت.
  static Color get greenOk => _mode(const Color(0xFF175E39), const Color(0xFF6BD39A));
  static Color get greenOkSoft => _mode(const Color(0xFFEAF5EE), const Color(0xFF17322A));

  /// الحجاب ورا الشيت السفلي.
  static const scrim = Color(0x8C0B2A33); // rgba(11,42,51,.55)

  /// الأرضية القديمة — اتشالت لصالح [ivory]. باقية عشان أي مرجع قديم
  /// يتلقط في المراجعة بدل ما يقع في التشغيل.
  @Deprecated('الأرضية بقت F.ivory')
  static const ground = ivory;

  // ------------------------------------------------- الحدود الدنيا (قواعد)
  /// كبار السن أول مستخدم — الأحجام دي حد أدنى مش اقتراح.
  static const minBodySize = 20.0;
  static const minTapTarget = 56.0;
  static const primaryButtonHeight = 64.0;

  /// أصغر نص مسموح بيه في أي مكان في التطبيق — **أعلى** من كابشن التصميم
  /// (١١–١٣) والـkicker (١٠). سلّم التصميم تحت مسجّل بالكامل للمرجعية،
  /// لكن ولا ودجت هنا بترسم أقل من ده.
  static const minTextSize = 17.0;

  /// أسماء الأدوية.
  static const medicationNameSize = 24.0;

  // ------------------------------------------- نمط كبار السن (المخطط ١٨)
  /// **أكبر** من الحدود العادية، مش مساوية ليها: اللي فتح النمط ده طلب
  /// صراحةً حاجة أكبر من العادي.
  static const elderTextSize = 24.0;
  static const elderTitleSize = 34.0;
  static const elderNameSize = 32.0;
  static const elderPrimaryButtonHeight = 80.0;
  static const elderSecondaryButtonHeight = 64.0;

  // ----------------------------------------------------- سلّم الخط (README)
  static const display1 = 46.0;
  static const display2 = 38.0;
  static const display3 = 34.0;
  static const screenTitleSize = 25.0;
  static const subtitleSize = 23.0;
  static const sectionHeadSize = 19.0;
  static const body1 = 16.5, body2 = 16.0, body3 = 15.5, body4 = 15.0;
  static const rowLabel1 = 14.5, rowLabel2 = 14.0;
  static const secondary1 = 13.0, secondary2 = 12.5;
  static const caption1 = 11.5, caption2 = 11.0;
  static const kicker1 = 10.0, kicker2 = 9.5;

  /// تباعد حروف الـkicker — ‎.14em. **للاتيني بس** — العربي متصل ومش بيتتبّع.
  static const kickerTracking = 0.14;

  // ------------------------------------------- تدرّج الابن (كثافة أعلى)
  /// **مقاسات الابن، جنب مقاسات الأب — مش بدالها.**
  ///
  /// «المريض ~٧٢ سنة… ومقدّم الرعاية شاب شغّال بيبص بسرعة» — دول مستخدمين
  /// مختلفين على نفس الهوية. الحدود اللي فوق (`minBodySize` ٢٠،
  /// `minTapTarget` ٥٦) اتكتبت لراجل بنضارة قراية تحت ضغط، وهي **حدود
  /// دنيا مش اقتراح** — فما بتصغرش. الابن بيفتح التطبيق تلات ثواني بين
  /// اجتماعين وعايز يشوف اليوم كله من غير ما يلفّ.
  ///
  /// **نفس اللوحة، نفس الخطوط العربية، نفس الـRTL** — الكثافة بس هي اللي
  /// بتتغيّر، والقيم دي مأخوذة من سلّم الخط اللي فوق (`body2`، `body4`،
  /// `rowLabel2`، `secondary2`) مش مخترعة.
  ///
  /// **وما تتكتبش برّه `lib/features/care/`** — اختبار بيقرا `lib/` ويوقع
  /// لو `F.care…` ظهر في أي شاشة تخص المريض.
  static const careTitleSize = sectionHeadSize; // ١٩ — عنوان الشاشة
  static const careHeadSize = body4; // ١٥ — عنوان قسم
  static const careBodySize = body2; // ١٦ — المتن
  static const careTextSize = rowLabel2; // ١٤ — الثانوي
  static const careMicroSize = secondary2; // ١٢٫٥ — التاريخ والوحدة

  /// أصغر نص مسموح عند الابن — نظير [minTextSize] في تدرّجه هو.
  static const careMinTextSize = careMicroSize;

  /// هدف اللمس عند الابن — قياسي للمنصّة، مش [minTapTarget] (٥٦).
  static const careTapTarget = 46.0;

  // ------------------------------------------- ألوان أقسام شاشة الابن
  /// **لون لكل قسم — هوية، مش زينة. واللون تالت دايماً.**
  ///
  /// كل قسم في «متابعة» بياخد لونه على **حد الكارت وشريطه الجانبي وعلامة
  /// صغيرة جنب العنوان** — مش على النص ومش على الأرضية. العنوان مكتوب
  /// بالعربي فوق كل قسم، فالهوية عمرها ما بتتحمل على اللون لوحده (شرط
  /// الترميز التاني، وهو اللي بيخلّي المجموعة دي مقبولة عند عمى الألوان).
  ///
  /// **اللي محجوز فضل محجوز:** الأحمر للطوارئ، والأزرق للمية، والكهرماني
  /// والبرتقالي لدرجات السلّم. والدهبي فضل أكثرهم تشبّعاً، فهو لسه اللي
  /// «بينطّ» — بس بقى معناه «القسم ده محتاجك» بدل ما يكون اللون الوحيد.
  ///
  /// **الأرقام دي متحسوبة مش متخمّنة.** كل لونين من ألوان الهوية بينهم
  /// ١٥ ΔE على الأقل برؤية عادية في الوضعين، وكل واحد فوق ٣:١ على
  /// الأرضيات التلاتة — ما عدا الدهبي النهاري (١٫٧٩، الدين المعروف؛
  /// ومعاه أيقونة وكلمة دايماً).
  ///
  /// **واتنين اترفضوا بالقياس، مش بالذوق:**
  ///  * وردي `#B33A6D` — ٩٫٨ ΔE بس من أحمر الطوارئ `#A81E26`.
  ///  * وطيني `#9A5326` — ١٣٫٤ ΔE من نفس الأحمر.
  /// لون بيلخبط مع الأحمر بيضيّع أغلى معنى في التطبيق، فالتحاليل نزلت
  /// لبرونزي غامق (`#573611`، ١٦٫٩ ΔE).
  ///
  /// **والمساحة ضيقة عن قصد**: بعد ما نشيل الأحمر والأزرق والدهبي
  /// والأخضرين وكل حاجة قريبة منهم، اللي فاضل **عايلتين بس** بيشتغلوا في
  /// الوضعين — بنفسجي وبرونزي. الحساب بيطلّعهم، مش الذوق.
  ///
  /// **والأخضرين ولاد عم بقرار المالك**: «جاية» بقت أخضر غامق و«اتاخدت»
  /// أخضر، فالزوج ده ١٤٫٠ ΔE نهاري و١٠٫٢ ليلي — تحت أرضية الـ١٥، وباقي
  /// الأزواج كلها فوقها. الاتنين بيتفرقوا بالإضاءة، والعنوان المكتوب فوق
  /// كل قسم هو اللي بيحمل الهوية أصلاً.
  static Color get careAccentDue => gold;
  /// **«جاية» أخضر غامق** (طلب المالك). في النهار هو `greenDeep` نفسه؛
  /// في الليل **لازم يفتح** — `greenDeep` بيقيس ١٫٥١:١ على كارت الليل،
  /// يعني القسم كان هيختفي. ده نفس الفخ اللي خدنا فيه «اتاخد» قبل كده.
  static Color get careAccentUpcoming =>
      _mode(greenDeep, const Color(0xFF2E9E85));
  static Color get careAccentTaken => green;
  static Color get careAccentSkipped =>
      _mode(const Color(0xFF5B6B7A), const Color(0xFF93A3B0));
  static Color get careAccentVisit =>
      _mode(const Color(0xFF4F256B), const Color(0xFF9765B8));
  static Color get careAccentLab =>
      _mode(const Color(0xFFA87A2A), const Color(0xFF8F6B24));

  /// **أحمر التنبيهات — استثناء تاني للأحمر، بقرار المالك وبنفس حدوده.**
  ///
  /// قاعدة «الأحمر للطوارئ وبس» كانت ليها استثناء واحد (قيمة تحليل برّه
  /// نطاق الورقة، جولة ٢١) و**بشرطين**: ملف واحد، و**من غير حشو** —
  /// الحبّاية الحمرا المليانة فاضلة للطوارئ لوحدها، وده اللي بيخلّي
  /// معناها محفوظ. تنبيهات الابن بتاخد نفس الشكل بالظبط: حد الكارت
  /// وشريطه وأيقونة ⚠ **وبس**، والنص بلون النص والأرضية زي ما هي.
  ///
  /// نفس قيم [outOfRangeInk] — ٥٫٢٣:١ في النهار و٥٫٠٩:١ في الليل على
  /// أسوأ أرضية. و`red_only_in_emergency_test` بيعرف الاسم ده وبيسمح بيه
  /// في ملف واحد بس، مع اختبار ودجت بيثبت إن مفيش حشو.
  static Color get careAlertInk => outOfRangeInk;

  static const carePad = s12;
  static const careRowGap = s8;
  static const careRadius = radiusTile;

  /// مقاسات موروثة من المرحلة الأولى — لسه مستعملة.
  static const questionSize = 27.0;
  static const bigTimeSize = 40.0;
  static const labelSize = 17.0;
  static const chipHeight = 64.0;

  // ------------------------------------------------------------ الأنصاف
  static const radiusChip = 8.0;
  static const radiusTile = 12.0; // 11–13
  static const radiusCard = 14.0; // 14–16
  static const radiusSection = 18.0;
  static const radiusLarge = 20.0; // 20–22
  static const radiusSheet = 26.0;

  /// الاسم القديم — نفس قيمة [radiusCard].
  static const radius = radiusCard;

  // ------------------------------------------------------------ المسافات
  static const s4 = 4.0, s6 = 6.0, s8 = 8.0, s10 = 10.0, s12 = 12.0;
  static const s14 = 14.0, s16 = 16.0, s18 = 18.0, s20 = 20.0;
  static const s22 = 22.0, s26 = 26.0, s30 = 30.0;
  static const gap = s16;

  // -------------------------------------------------------------- الظلال
  static const shadowCard = [
    BoxShadow(color: Color(0x1A0E2A33), offset: Offset(0, 8), blurRadius: 26),
  ];
  static const shadowMenu = [
    BoxShadow(color: Color(0x2E0E2A33), offset: Offset(0, 12), blurRadius: 30),
  ];
  static const shadowSheet = [
    BoxShadow(color: Color(0x3D000000), offset: Offset(0, -14), blurRadius: 40),
  ];
  static const shadowModalDark = [
    BoxShadow(color: Color(0x47000000), offset: Offset(0, 18), blurRadius: 46),
  ];

  // -------------------------------------------------------------- الحركة
  static const sheetDuration = Duration(milliseconds: 280);
  static const fadeDuration = Duration(milliseconds: 150);

  // -------------------------------------------------------------- الخطوط
  /// العناوين والعلامة.
  static const displayFamily = 'Alexandria';

  /// كل نصوص الواجهة.
  static const bodyFamily = 'IBM Plex Sans Arabic';

  /// أسماء الأدوية والأرقام — لاتيني في mono.
  ///
  /// IBM Plex Mono مفيهوش حروف عربي، ومن غير البديل العربي الحروف بتتفصل
  /// عن بعضها. عشان كده أي استخدام لـmono لازم يشيل الاحتياطي ده معاه.
  static const monoFamily = 'IBM Plex Mono';
  static const monoFallback = <String>[bodyFamily, 'Noto Sans Arabic', 'Arial'];

  /// الثيم بيتبني من قيم **الوضع الحالي** — نفس الاسم في النهار والليل،
  /// والجذر بيعيد البناء لما [darkMode] تتغيّر.
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: isDark ? Brightness.dark : Brightness.light,
        fontFamily: bodyFamily,
        scaffoldBackgroundColor: pageGround,
        colorScheme: ColorScheme.fromSeed(
          seedColor: green,
          brightness: isDark ? Brightness.dark : Brightness.light,
          primary: green,
          secondary: gold,
          surface: cardGround,
        ),
        // **شريط مصمت بلون الصفحة، من غير خط ولا ظل** (المالك، ٢٦ سبتمبر
        // ٢٠٢٦ — الخط والظل اترجعوا). مصمت: القايمة بتبدأ تحته والكلام عمره
        // ما بيبان من وراه؛ و`scrolledUnderElevation: 0` = ولا ظل ولا صبغة
        // لما المحتوى يتزحلق تحته.
        appBarTheme: AppBarTheme(
          backgroundColor: pageGround,
          foregroundColor: ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: displayFamily,
            fontSize: subtitleSize,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: displayFamily, fontSize: display1, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(fontFamily: displayFamily, fontSize: screenTitleSize, fontWeight: FontWeight.w700),
          titleLarge: TextStyle(fontFamily: displayFamily, fontSize: subtitleSize, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontSize: sectionHeadSize, fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(fontSize: minBodySize, height: 1.7),
          bodyMedium: TextStyle(fontSize: 18, height: 1.7),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(primaryButtonHeight),
            textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusCard)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(minTapTarget),
            textStyle: const TextStyle(fontSize: minTextSize),
            side: BorderSide(color: line),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusCard)),
          ),
        ),
      );
}
