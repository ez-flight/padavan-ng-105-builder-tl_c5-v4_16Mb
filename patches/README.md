# Патчи (patches/)

Патчи применяются `build.sh` к дереву `padavan-ng` после переключения на закреплённый
коммит `PADAVAN_COMMIT` из `variables`. Перед применением каждый патч проходит
`git apply --check`; любая ошибка останавливает сборку.

## Состав

- `patches-16m-profile.patch` — board-профиль `TL_C5-V4_16M`
  (`trunk/configs/boards/TPLINK/TL_C5-V4_16M/`): board.h, board.mk, kernel-3.4.x.config,
  partitions.config с 16-МиБ разметкой Flash (Firmware до 0xFA0000, служебные
  разделы в вершине 16 МиБ).

- `patches-wan-led.patch` — **WAN_GUARD + LED + SFTP-из-WAN**:
  - WAN_GUARD: цепочки `WAN_GUARD`/`WAN_GUARD6` в `trunk/user/rc/firewall_ex.c`
    закрывают WAN от входящих соединений со стороны интернета. Разрешены только
    `ESTABLISHED,RELATED` и DHCP/DHCPv6.
  - AWG3/WireGuard сервер: его UDP-порт (`vpns_wg_port`, по умолчанию 51820,
    задаётся на странице VPN-сервера) открывается из WAN **только пока сервер
    включён** (`vpns_enable=1` и тип WireGuard). Сервер выключен — порт закрыт.
  - SFTP/SSH из WAN: если в меню SSH включён
    «Доступ к SSH-серверу из WAN» (`sshd_enable != 0` и `sshd_wopen = 1`),
    порт SSH (TCP 22, в него же входит подсистема SFTP) автоматически открывается
    из WAN через цепочку защиты от брутфорса `BFP_LIMIT`. Чекбокс добавлен в
    раздел SSH страницы «Службы» (`Advanced_Services_Content.asp`), тот же NVRAM
    `sshd_wopen`, что и на странице файрвола — обе страницы работают синхронно.
    По умолчанию (заводской NVRAM `sshd_wopen=0`) WAN закрыт полностью.
  - LED: двухцветный WAN LED (GPIO9 зелёный / GPIO10 оранжевый) по `led.7z`:
    новый `trunk/user/rc/my_control_led.h` и вызовы в `rc.c`, `detect_link.c`,
    `detect_internet.c`, `net_wan.c`. Зелёный = интернет есть, оранжевый = линк есть,
    интернета нет; погас = линка нет.

## Чего здесь НЕТ и почему

Отдельный патч Zapret2 не нужен: целевой репозиторий `padavan-ng-tl_c5-v4_16Mb`
уже содержит штатную интеграцию Zapret2 (`trunk/user/zapret/`, опция
`CONFIG_FIRMWARE_INCLUDE_ZAPRET2`, страница «Службы → Zapret», NFQUEUE-модули ядра
включаются в `build_firmware.sh`). Включается только опцией в `build.config`.

- `patches-gcc15-bool.patch` — совместимость с GCC 15 (host): `typedef unsigned char bool;`
  в заголовках pppd конфликтует со стандартом C23 (в GCC 15 `bool` — ключевое слово).
  Typedef обёрнут в проверку `__STDC_VERSION__ < 202311L`. Затронуты
  `accel-pptpd/pptpd-1.3.3/plugins/pppd.h` и `pppd/pppd/pppd.h`.

## Порядок применения

`build.sh` применяет патчи в алфавитном порядке:
`patches-16m-profile.patch` → `patches-gcc15-bool.patch` → `patches-wan-led.patch`.
Файлы не пересекаются.

## Обновление патчей

После смены `PADAVAN_COMMIT` в `variables` проверьте каждый патч:

```bash
git -C padavan-ng apply --check /полный/путь/patches/<имя>.patch
```

Если проверка падает — пересоздайте патч от нового коммита, не правьте его «вслепую».
