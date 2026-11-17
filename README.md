# padavan-ng-builder для TP-Link Archer C5 V4 (16M)

Builder-проект для сборки прошивки **Padavan (padavan-ng)** под роутер
**TP-Link Archer C5 V4 с Flash 16 МиБ** (SoC MT7620).

Отличия от исходного форка (`chihpuh777/padavan-ng-builder-tl_c5-v4_16Mb`):

- **WAN_GUARD** — WAN закрыт от всех входящих соединений со стороны интернета
  (цепочки `WAN_GUARD`/`WAN_GUARD6` в firewall). Разрешены только
  `ESTABLISHED,RELATED`, DHCP/DHCPv6 и UDP-порт AmneziaWG (по умолчанию 51821,
  NVRAM `wan_guard_awg_port`, `0` отключает исключение).
- **SFTP/SSH из WAN** — чекбокс «Доступ к SSH-серверу из WAN» в разделе SSH
  страницы «Службы» (`sshd_wopen`). При включении порт SSH (TCP 22, туда же
  входит подсистема SFTP) автоматически открывается из WAN через цепочку
  защиты от брутфорса. По умолчанию WAN закрыт полностью.
- **Двухцветный WAN LED** (GPIO9 зелёный / GPIO10 оранжевый): зелёный — интернет
  есть, оранжевый — линк есть, интернета нет, погас — линка нет.
- **Zapret2 (nfqws2)** — штатная интеграция из репозитория исходников
  (`CONFIG_FIRMWARE_INCLUDE_ZAPRET2=y`), страница «Службы → Zapret».
- **AmneziaWG** — `CONFIG_FIRMWARE_INCLUDE_AMNEZIAWG=y`.
- **Воспроизводимость** — коммит исходников зафиксирован в `variables`
  (`PADAVAN_COMMIT`, не `HEAD`); `build.sh` сверяет SHA после clone/fetch.
- **`build.sh`** — локальная сборка с проверками: `set -euo pipefail`, проверка
  команд и конфигурации, `git apply --check` каждого патча перед применением.

## Состав

```text
build.config      # профиль TL_C5-V4_16M и опции сборки
variables         # репозиторий/ветка/коммит padavan-ng, URL toolchain
build.sh          # локальная сборка (см. BUILD-INSTRUCTION-RU.md)
patches/          # 16m-профиль платы; WAN_GUARD+LED+SFTP-из-WAN (с README)
.github/workflows/build.yml   # сборка через GitHub Actions
```

## Сборка

Локально (Linux, нужны git, wget, tar, make, gcc, patch):

```bash
tmux new-session -d -s padavan-build "cd <путь к репозиторию> && mkdir -p logs && ./build.sh 2>&1 | tee logs/build-$(date +%Y%m%d-%H%M%S).log"
```

Через GitHub Actions: Actions → Build firmware → Run workflow.

Готовый образ: `padavan-ng/trunk/images/TL_C5-V4_16M_*.bin`.
Полная инструкция (tmux, логи, возобновление, остановка): `BUILD-INSTRUCTION-RU.md`.

## Важно

- Профиль рассчитан на **16-МиБ разметку Flash** (Firmware до 0xFA0000,
  служебные разделы в вершине 16 МиБ). Не шейте на устройство с другой разметкой.
- После обновления прошивки рекомендуется полный сброс настроек.
- Патчи в `patches/` привязаны к коммиту из `variables`; после его смены
  проверяйте `git apply --check` (см. `patches/README.md`).
