#!/bin/bash
# Брендинг исходников RustDesk 1.5.0 под itdesk (ITW Online, для CI). Запуск из корня исходников.
# Проверяет каждое изменение; при неудаче — выход с ошибкой (сборка остановится).
#
# =====================================================================================
# ЧТО ЭТО ЗА СКРИПТ (простыми словами)
# =====================================================================================
# RustDesk — бесплатная программа удалённого доступа (как TeamViewer): с её помощью
#   можно видеть экран другого компьютера и управлять им через интернет.
# Мы берём её исходный код (текст программы) версии 1.5.0 и «перекрашиваем» под себя:
#   - программа сразу подключается к НАШЕМУ серверу rd.itwonline.ru (а не к общему);
#   - знает ключ нашего сервера (чтобы убедиться, что сервер настоящий);
#   - эти настройки ВИДНЫ в окне настроек (их можно посмотреть и поменять);
#   - называется «itdesk» и имеет наши иконки на Windows, macOS, Android и Linux.
# «Брендинг» — так называют замену названия, логотипа и настроек на свои.
#
# КТО ЗАПУСКАЕТ:
#   GitHub Actions — это «робот-сборщик» на серверах GitHub: по нашей команде он скачивает
#   исходники, запускает этот скрипт, а потом собирает готовые программы (установщики).
#   Репозиторий: gussenecco-arch/rustdesk, ветка itdesk-all.
#   «Сборка» — превращение исходного текста программы в готовый файл, который можно установить.
#
# КАК ЗАПУСТИТЬ ВРУЧНУЮ (если очень надо):
#   cd папка_с_исходниками_rustdesk && bash itdesk-brand.sh
#   Рядом должна лежать папка .github/itdesk-icons с нашими иконками.
#
# ВАЖНО: если хоть одна замена не сработала — скрипт завершится с ошибкой,
#   и GitHub Actions остановит сборку. Так мы не выпустим «наполовину перекрашенную» программу.
# =====================================================================================

# set -e  — остановиться при первой же ошибке любой команды;
# set -u  — ошибка, если используется переменная, которую забыли задать;
# set -o pipefail — ошибка в середине цепочки команд «a | b» тоже считается ошибкой.
set -euo pipefail
# Наши значения:
#   SERVER — адрес сервера, через который клиенты находят друг друга (ID-сервер);
#   API    — адрес для входа в учётную запись и адресной книги (BetterDesk офиса через NPM, с 31.10.2026);
#   KEY    — открытый ключ сервера (не секрет, его можно показывать);
#   NAME   — название программы, которое увидит пользователь.
SERVER="rd.itwonline.ru"; API="https://rd-api.itwonline.ru"
KEY="uIyvAIIqKmt8sZWuKEfkfxGnm9U1iWxOtxcafU32Sko="; NAME="itdesk"
# DESC — описание программы: телефоны техподдержки и сайт (видно в свойствах файла и в пакетах).
# Латиницей: так надёжнее для файлов ресурсов Windows и пакетов Linux.
DESC="itdesk - ITW Online support: 8 988 145-44-31, 8 862 444-44-31, itwonline.ru"
# Папка с нашими иконками (лежит в репозитории на GitHub).
ICONS=.github/itdesk-icons
# SED — наша «обёртка» над программой sed (sed умеет искать и заменять текст прямо в файле).
# Беда в том, что sed на Linux (GNU) и sed на macOS пишутся по-разному:
#   на Linux:  sed -i -E ...      на macOS:  sed -i '' -E ...
# Поэтому сначала проверяем, какой sed у нас (у GNU sed есть --version), и вызываем правильно.
# -i — менять файл на месте; -E — «расширенные» регулярные выражения (шаблоны поиска).
SED() { if sed --version >/dev/null 2>&1; then sed -i -E "$@"; else sed -i '' -E "$@"; fi; }
# CFG — главный файл настроек RustDesk (написан на языке Rust). В нём зашиты сервер, ключ, имя.
CFG=libs/hbb_common/src/config.rs

# 1. сервер, ключ, имя
# Подробнее: в config.rs заменяем три строчки:
#   - RENDEZVOUS_SERVERS — список серверов «по умолчанию» → ставим только наш rd.itwonline.ru;
#   - RS_PUB_KEY         — ключ сервера → ставим наш ключ;
#   - RwLock::new("RustDesk") — название программы → "itdesk".
# Знак | здесь — просто разделитель в команде sed «s|что искать|на что заменить|».
SED "s|^pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[.*\];|pub const RENDEZVOUS_SERVERS: \&[\&str] = \&[\"$SERVER\"];|" $CFG
SED "s|^pub const RS_PUB_KEY: &str = \".*\";|pub const RS_PUB_KEY: \&str = \"$KEY\";|" $CFG
SED "s|RwLock::new\(\"RustDesk\".to_owned\(\)\)|RwLock::new(\"$NAME\".to_owned())|" $CFG
# 2. значения по умолчанию в настройках (видны в UI, можно изменить): ID-сервер, API-сервер (вход), ключ
# Подробнее: изначально DEFAULT_SETTINGS — пустой список. Мы заполняем его тремя парами
#   «имя настройки → значение». UI (окно программы) показывает их в настройках сети,
#   поэтому пользователь видит, к какому серверу подключён, и при желании может поменять.
SED "s|^    pub static ref DEFAULT_SETTINGS: RwLock<HashMap<String, String>> = Default::default\(\);|    pub static ref DEFAULT_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from([(\"custom-rendezvous-server\".to_owned(), \"$SERVER\".to_owned()), (\"api-server\".to_owned(), \"$API\".to_owned()), (\"key\".to_owned(), \"$KEY\".to_owned())]));|" $CFG
# 3. имя на всех платформах
# Окно программы сделано на Flutter — это набор инструментов от Google, позволяющий
#   написать интерфейс один раз и запускать его на Windows, macOS, Linux и Android.
# Android: меняем applicationId — «паспортное имя» приложения в телефоне.
#   С другим applicationId наш itdesk ставится РЯДОМ с обычным RustDesk, а не вместо него.
#   (Файл build.gradle есть не во всех версиях — поэтому сначала проверяем, что он существует.)
[ -f flutter/android/app/build.gradle ] && SED 's|applicationId "com.carriez.flutter_hbb"|applicationId "ru.itwonline.itdesk"|' flutter/android/app/build.gradle
# Android: подписи под иконками на экране телефона (основное приложение и служба ввода).
SED "s|android:label=\"RustDesk\"|android:label=\"$NAME\"|; s|android:label=\"RustDesk Input\"|android:label=\"$NAME Input\"|" flutter/android/app/src/main/AndroidManifest.xml
# macOS: название программы в файле описания приложения Info.plist.
SED "s|<string>\\\$\(PRODUCT_NAME\)</string>|<string>$NAME</string>|" flutter/macos/Runner/Info.plist
# Windows: название и описание в свойствах .exe-файла (видно в «Свойства → Подробно»).
SED "s|VALUE \"ProductName\", \"RustDesk\"|VALUE \"ProductName\", \"$NAME\"|; s|VALUE \"FileDescription\", \"RustDesk Remote Desktop\"|VALUE \"FileDescription\", \"$DESC\"|; s|VALUE \"CompanyName\", \"[^\"]*\"|VALUE \"CompanyName\", \"ITW Online, itwonline.ru\"|" flutter/windows/runner/Runner.rc
# Linux: название в ярлыках меню приложений (.desktop-файлы).
SED "s|^Name=RustDesk$|Name=$NAME|" res/rustdesk.desktop res/rustdesk-link.desktop
# 4. иконки
# Просто копируем наши картинки поверх стандартных картинок RustDesk.
# Общие иконки (разных размеров) — в папку res/.
# 4. описание с телефонами техподдержки
# Linux: строка «Comment» в ярлыке и «Description» в deb-пакете; macOS: строка копирайта (видна в «О программе»).
SED "s|^Comment=Remote Desktop$|Comment=$DESC|" res/rustdesk.desktop
SED "s|^Description: A remote control software.$|Description: $DESC|; s|^Homepage: https://rustdesk.com$|Homepage: https://itwonline.ru|" build.py
SED "s|^PRODUCT_COPYRIGHT = .*|PRODUCT_COPYRIGHT = $DESC|" flutter/macos/Runner/Configs/AppInfo.xcconfig
cp $ICONS/32x32.png $ICONS/64x64.png $ICONS/128x128.png $ICONS/128x128@2x.png $ICONS/icon.png $ICONS/mac-icon.png $ICONS/icon.ico $ICONS/scalable.svg res/
# Иконка .exe-файла на Windows.
cp $ICONS/app_icon.ico flutter/windows/runner/resources/app_icon.ico
# Иконка приложения на macOS (формат .icns).
cp $ICONS/AppIcon.icns flutter/macos/Runner/AppIcon.icns
# Android хочет иконки под разную плотность экрана (mdpi — простые экраны, xxxhdpi — очень чёткие).
# Цикл for копирует картинки для каждой плотности в свою папку.
for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do cp $ICONS/mipmap-$d/*.png flutter/android/app/src/main/res/mipmap-$d/; done
# Android: фон под иконкой меняем с белого (#ffffff) на чёрный (#000000).
SED 's|#ffffff|#000000|' flutter/android/app/src/main/res/values/ic_launcher_background.xml
# Иконка внутри самого окна программы (если такой файл есть; «|| true» — не считать ошибкой, если нет).
[ -f flutter/assets/icon.png ] && cp $ICONS/icon.png flutter/assets/icon.png || true

# проверки
# Каждая строка ниже ищет в файле нужный текст (grep -q — «тихо», только да/нет).
# Если текст не найден — grep вернёт ошибку, и благодаря set -e скрипт сразу остановится,
# а вместе с ним и вся сборка на GitHub Actions.
# Сервер прописан в RENDEZVOUS_SERVERS?
# 7. Имя исполняемого файла Windows — itdesk.exe.
# Зачем: ярлык при установке создаётся по имени программы (get_app_name() = itdesk),
# а собирался файл rustdesk.exe — ярлык указывал на несуществующий itdesk.exe.
SED "s|^set\(BINARY_NAME \"rustdesk\"\)|set(BINARY_NAME \"$NAME\")|" flutter/windows/CMakeLists.txt
SED "s|^project\(rustdesk LANGUAGES CXX\)|project($NAME LANGUAGES CXX)|" flutter/windows/CMakeLists.txt
SED "s|std::wstring app_name = L\"RustDesk\";|std::wstring app_name = L\"$NAME\";|" flutter/windows/runner/main.cpp
SED "s|VALUE \"InternalName\", \"rustdesk\"|VALUE \"InternalName\", \"$NAME\"|; s|VALUE \"OriginalFilename\", \"rustdesk.exe\"|VALUE \"OriginalFilename\", \"$NAME.exe\"|" flutter/windows/runner/Runner.rc
grep -q "set(BINARY_NAME \"$NAME\")" flutter/windows/CMakeLists.txt
grep -q "std::wstring app_name = L\"$NAME\"" flutter/windows/runner/main.cpp
grep -q "\"OriginalFilename\", \"$NAME.exe\"" flutter/windows/runner/Runner.rc

grep -q "\"$SERVER\"\];" $CFG
# Ключ на месте?
grep -q "$KEY" $CFG
# Имя программы заменено?
grep -q "RwLock::new(\"$NAME\"" $CFG
# Адрес для входа (API) попал в настройки по умолчанию?
grep -q "(\"api-server\".to_owned(), \"$API\"" $CFG
# Имя на Android, macOS, Windows, Linux заменено?
grep -q "android:label=\"$NAME\"" flutter/android/app/src/main/AndroidManifest.xml
grep -q "<string>$NAME</string>" flutter/macos/Runner/Info.plist
grep -q "\"ProductName\", \"$NAME\"" flutter/windows/runner/Runner.rc
grep -q "^Name=$NAME$" res/rustdesk.desktop
# Иконка macOS скопировалась? (cmp -s сравнивает два файла байт в байт.)
cmp -s $ICONS/AppIcon.icns flutter/macos/Runner/AppIcon.icns
# Всё прошло — сообщаем об успехе.
grep -q "8 988 145-44-31" flutter/windows/runner/Runner.rc
grep -q "8 862 444-44-31" build.py
grep -q "itwonline.ru" res/rustdesk.desktop
echo "itdesk branding OK"
# И печатаем получившиеся строки из config.rs, чтобы их было видно в журнале сборки.
grep -nE "^pub const (RENDEZVOUS_SERVERS|RS_PUB_KEY)|DEFAULT_SETTINGS: RwLock" $CFG
