# HANDOFF: подготовка builder-проекта TL_C5-V4_16M

Дата: 2026-11-17. Сервер: EMBY.
Проект: `/home/emby/Project/archer-c5-v4-padavan-nfqws2/padavan-ng-builder-tl_c5-v4_16Mb`
Upstream: `https://github.com/chihpuh777/padavan-ng-builder-tl_c5-v4_16Mb` (проверен `git remote -v`).
Сборка НЕ запускалась. Прошивка не записывалась. В GitHub не публиковалось (только локальные коммиты).

## Что сделано

1. **build.config** переписан в непротиворечивом виде: убран дублирующий «merge-фрагмент»
   (одни и те же ключи встречались дважды с разными значениями). Каждая опция задана
   один раз. Профиль: `CONFIG_VENDOR=TPLINK`, `CONFIG_PRODUCT=MT7620`,
   `CONFIG_FIRMWARE_PRODUCT_ID="TL_C5-V4_16M"`; переопределений на другой профиль нет.
   Включено: `CONFIG_FIRMWARE_INCLUDE_ZAPRET2=y` (Zapret2/nfqws2 — штатная опция целевого
   репозитория), `CONFIG_FIRMWARE_INCLUDE_AMNEZIAWG=y`, `CONFIG_FIRMWARE_INCLUDE_IPSET=y`,
   SFTP, Samba (SMBD), Dropbear, USB/NTFS-3G/exFAT/ext4/FUSE, ZRAM, LANG_RU.
   Выключено осознанно: SHORTCUT_FE (чтобы потоки не обходили NFQUEUE), OpenVPN и
   WireGuard (VPN — AmneziaWG; при AMNEZIAWG=y upstream сам выключает WIREGUARD),
   HTTPS/EAP-PEAP/DDNS_SSL/OPENSSL_EXE (экономия места), Transmission/XUPNPD/FTPD.

2. **WAN_GUARD + LED + SFTP-из-WAN** — один патч `patches/patches-wan-led.patch`,
   адаптирован и пересоздан под коммит `3b097a0e` (проверен `git apply --check` и
   round-trip применение на чистом клоне):
   - WAN_GUARD: цепочки `WAN_GUARD`/`WAN_GUARD6` в `firewall_ex.c`; разрешены
     ESTABLISHED,RELATED + DHCP/DHCPv6. Порт AWG3-сервера (`vpns_wg_port`,
     по умолчанию 51820) открывается из WAN только пока сервер включён
     (`vpns_enable=1`, тип WireGuard).
   - SFTP/SSH из WAN: при включённом чекбоксе «Доступ к SSH-серверу из WAN»
     (`sshd_wopen=1`, штатный NVRAM) WAN_GUARD автоматически пропускает TCP 22
     (SSH + подсистема SFTP) через цепочку антибрутфорса `BFP_LIMIT`. Чекбокс и поле
     внешнего порта добавлены в раздел SSH страницы «Службы»
     (`Advanced_Services_Content.asp`), синхронизированы со страницей файрвола
     (тот же NVRAM). По умолчанию WAN закрыт полностью.
   - LED: `my_control_led.h` (GPIO9 зелёный / GPIO10 оранжевый) из `led.7z`,
     вызовы в `rc.c`, `detect_link.c`, `detect_internet.c`, `net_wan.c`.

3. **Zapret2 (nfqws2)** — НЕ патчем: целевой репозиторий `padavan-ng-tl_c5-v4_16Mb`
   уже содержит штатную интеграцию (`trunk/user/zapret/`, Zapret2 1.0.6,
   `CONFIG_FIRMWARE_INCLUDE_ZAPRET2`, страница Advanced_Services_Zapret.asp,
   NFQUEUE включается в build_firmware.sh). Прежний `native-nfqws2.patch` (от дерева
   hadzhioglu) не применялся к этому репозиторию и удалён, payload `files/nfqws2`
   удалён как неиспользуемый.

4. **AmneziaWG** — `CONFIG_FIRMWARE_INCLUDE_AMNEZIAWG=y`; модуль ядра и утилиты
   собираются штатно (wireguard/amneziawg-tools в репозитории).

5. **Профиль 16M** — `patches/patches-16m-profile.patch` добавляет board-профиль
   `TL_C5-V4_16M` (board.h, board.mk, kernel-3.4.x.config, partitions.config:
   Firmware [0x20000,0xFA0000) до 15.5 МиБ, служебные разделы в вершине 16 МиБ).

6. **Воспроизводимость** — `variables`: `PADAVAN_COMMIT=3b097a0ebc12447842d6021c27327e77cd6e0157`
   (`git ls-remote … HEAD`, 2026-11-17), не `HEAD`. `build.sh` клонирует
   `PADAVAN_REPO` сам (init + `git fetch --depth 1` на коммит), от `source-current`
   и прочих локальных деревьев не зависит; HEAD клона сверяется с хешем.

7. **build.sh** — создан: `set -euo pipefail`; проверка команд (git, wget, tar, make,
   gcc, patch, awk, sed, grep); проверка variables (коммит != HEAD) и build.config
   (профиль TL_C5-V4_16M, ZAPRET2=y, AMNEZIAWG=y); clone+checkout с контролем SHA;
   каждый патч из `patches/` — `git apply --check` перед применением; toolchain;
   `clear_tree.sh` + `build_firmware.sh`; поиск образа. `chmod +x`, `bash -n` PASS.

8. **BUILD-INSTRUCTION-RU.md** — создан: tmux-запуск одной командой, attach/отсоединение,
   возобновление, поиск BIN (`padavan-ng/trunk/images/*.bin`), остановка сборки.

9. **Workflow** — в `build.yml` добавлен шаг применения `patches/*.patch` после
   клонирования исходников, до сборки.

10. **patches/README.md** — документация состава, SFTP-исключения и причин отказа
    от отдельного патча Zapret2.

## Проверки (без компиляции)

- `bash -n build.sh` — PASS.
- `git apply --check` обоих патчей против чистого клона `padavan-ng` на `3b097a0e` — PASS;
  round-trip (apply на чистом дереве) — PASS.
- Ключевые опции build.config уникальны и корректны (grep-проверка).
- Структура проекта не сломана; сборка/прошивка/push не выполнялись.

## Как собирать

См. `BUILD-INSTRUCTION-RU.md`. Кратко:

```bash
tmux new-session -d -s padavan-build "cd /home/emby/Project/archer-c5-v4-padavan-nfqws2/padavan-ng-builder-tl_c5-v4_16Mb && mkdir -p logs && ./build.sh 2>&1 | tee logs/build-$(date +%Y%m%d-%H%M%S).log"
```

Временный клон для проверки патчей (`.runtime/builder-patchcheck/padavan-ng`) создан и удалён после успешных проверок.
