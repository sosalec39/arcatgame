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
bash deploy.sh ВАШ_ЛОГИН/ИМЯ_РЕПО
```

Или вручную:
1. Скачайте `ARCatGame.ipa` из GitHub Actions
2. Скопируйте на iPhone: `scp ARCatGame.ipa mobile@192.168.1.168:/var/mobile/Documents/`
3. SSH на телефон: `ssh mobile@192.168.1.168`
4. Установите: `trollstorehelper install /var/mobile/Documents/ARCatGame.ipa`

## Требования

- iPhone с ARKit (iPhone 6s+)
- iOS 15.0+
- TrollStore установлен на устройстве
