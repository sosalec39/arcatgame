# AR Cat Game 🐱

AR-игра на iOS: ловите виртуального кота в своей комнате!

## Структура

```
ARCatGame/
├── ARCatGame/
│   ├── AppDelegate.swift            # точка входа
│   ├── ScanRoomViewController.swift # сканирование комнаты
│   ├── GameViewController.swift     # основная игра
│   ├── CatEntity.swift              # AR-сущность кота
│   ├── cat.usdz                     # 3D модель кота
│   ├── Info.plist
│   └── Assets.xcassets/
└── ARCatGame.xcodeproj/
```

## Как играть

1. Откройте приложение → наведите камеру на пол и стены
2. Двигайте телефоном по комнате пока прогресс-бар не заполнится
3. Нажмите **«Начать игру!»**
4. Коты появятся на поверхностях вокруг вас
5. Нажмите на кота чтобы поймать его и получить очко
6. Коты убегают через ~15 секунд — не зевайте!

## Сборка через GitHub Actions

1. Залейте этот репозиторий на GitHub
2. GitHub Actions автоматически соберёт IPA при пуше в `main`
3. Скачайте `ARCatGame-ipa` из вкладки **Actions → Artifacts**

## Установка через TrollStore (локально)

```bash
# Требует: sshpass, gh CLI
bash deploy.sh sosalec39/arcatgame
```

Скрипт сам скачает свежий IPA из Actions, закинет на телефон и установит.

### Особенности этого устройства

Пара вещей, на которые я наткнулся при установке:

- **`scp` не работает** — sshd на телефоне его отклоняет. Файл передаётся
  через пайп: `ssh mobile@IP "cat > /path" < file.ipa`
- **`trollstorehelper` требует root.** У Dopamine нет `jbctl rootexec`
  (там только `proc_set_debugged`, `trustcache`, `update`), поэтому нужен
  `echo 123 | sudo -S trollstorehelper install ...`
- **SSH только по паролю** — нужны флаги
  `-o PubkeyAuthentication=no -o PreferredAuthentications=password`,
  иначе получите `Too many authentication failures`

## Требования

- iPhone с ARKit (iPhone 6s+)
- iOS 15.0+
- TrollStore установлен на устройстве
