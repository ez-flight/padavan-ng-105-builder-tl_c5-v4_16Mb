# Сборка прошивки Padavan для TP-Link Archer C5 V4 (16M)

Проект: `/home/emby/Project/archer-c5-v4-padavan-nfqws2/padavan-ng-builder-tl_c5-v4_16Mb`

Профиль: `TL_C5-V4_16M`. Включены: Zapret2 (nfqws2), AmneziaWG, SFTP (с чекбоксом доступа из WAN в меню SSH), Samba, USB-накопители (NTFS-3G/exFAT/ext4), IPSet, ZRAM. WAN закрыт входящим соединениям цепочками `WAN_GUARD`/`WAN_GUARD6` (патч `patches/patches-wan-led.patch`); LED WAN — двухцветный (GPIO9 зелёный / GPIO10 оранжевый).

## 1. Запуск сборки в tmux (одной командой)

```bash
tmux new-session -d -s padavan-build "cd /home/emby/Project/archer-c5-v4-padavan-nfqws2/padavan-ng-builder-tl_c5-v4_16Mb && mkdir -p logs && ./build.sh 2>&1 | tee logs/build-\$(date +%Y%m%d-%H%M%S).log"
```

## 2. Подключение к сессии и просмотр логов

```bash
tmux attach -t padavan-build        # живой вывод сборки; отсоединение: Ctrl+B, затем D
```

Логи дублируются в файл:

```bash
ls -t logs/build-*.log | head -1    # последний лог
tail -f "$(ls -t logs/build-*.log | head -1)"
```

## 3. Возобновление после отсоединения

Сессия tmux переживает отключение SSH. Вернуться:

```bash
tmux attach -t padavan-build
```

Если сессия завершилась, список сессий: `tmux ls`.

## 4. Поиск готового BIN

```bash
ls -lt /home/emby/Project/archer-c5-v4-padavan-nfqws2/padavan-ng-builder-tl_c5-v4_16Mb/padavan-ng/trunk/images/*.bin
```

Готовый образ имеет вид `TL_C5-V4_16M_3.4.3.9L-XXX-<hash>.bin` (маска: `padavan-ng/trunk/images/*.bin`).

## 5. Остановка сборки

```bash
tmux send-keys -t padavan-build C-c     # мягкая остановка (прервать make)
# либо полностью:
tmux kill-session -t padavan-build
```

## Примечания

- Первый запуск скачивает исходники `padavan-ng` и toolchain (нужен интернет; десятки минут только на подготовку).
- Полная сборка занимает от ~1 часа и больше в зависимости от CPU.
- Сборка не запускается без tmux запрещением — можно и напрямую `./build.sh`, но при обрыве SSH процесс погибнет.
- Перед прошивкой убедитесь, что разметка целевая: профиль `TL_C5-V4_16M` рассчитан на 16-МиБ Flash.
